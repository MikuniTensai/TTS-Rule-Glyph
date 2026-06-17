import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioManager instance = AudioManager._internal();
  
  bool isMuted = false;
  
  // Audio players cache for overlapping sounds
  final Map<String, AudioPlayer> _players = {};
  
  // Cached synthesized sound bytes
  final Map<String, Uint8List> _soundBytes = {};

  AudioManager._internal();

  /// Retrieve or create an AudioPlayer for a sound
  AudioPlayer _getPlayer(String name) {
    if (!_players.containsKey(name)) {
      final player = AudioPlayer();
      _players[name] = player;
    }
    return _players[name]!;
  }

  /// Retrieve or generate WAV bytes for a sound
  Uint8List _getSoundBytes(String name) {
    if (!_soundBytes.containsKey(name)) {
      _soundBytes[name] = _synthesizeSound(name);
    }
    return _soundBytes[name]!;
  }

  /// Synthesize a sound by name
  Uint8List _synthesizeSound(String name) {
    const int sampleRate = 22050; // Use 22050Hz to save CPU and RAM for synthesis
    if (name == 'move') {
      return _synthesizeMove(sampleRate);
    } else if (name == 'rule') {
      return _synthesizeRuleChange(sampleRate);
    } else if (name == 'merge') {
      return _synthesizeMerge(sampleRate);
    } else if (name == 'unlock') {
      return _synthesizeUnlock(sampleRate);
    } else if (name == 'fail') {
      return _synthesizeFail(sampleRate);
    } else if (name == 'win') {
      return _synthesizeWin(sampleRate);
    } else if (name == 'erase') {
      return _synthesizeErase(sampleRate);
    } else {
      return _synthesizeMove(sampleRate);
    }
  }

  Future<void> playSfx(String name) async {
    if (isMuted) return;
    
    try {
      final bytes = _getSoundBytes(name);
      final player = _getPlayer(name);
      // Play raw WAV bytes directly
      await player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (e) {
      // ignore audio device errors
    }
  }

  void toggleMute() {
    isMuted = !isMuted;
    if (isMuted) {
      for (var player in _players.values) {
        player.stop();
      }
    }
  }

  Future<void> playMove() => playSfx('move');
  Future<void> playErase() => playSfx('erase');
  Future<void> playFail() => playSfx('fail');
  Future<void> playRuleChange() => playSfx('rule');
  Future<void> playTimerTick() => playSfx('erase');
  Future<void> playWin() => playSfx('win');
  Future<void> playMerge() => playSfx('merge');
  Future<void> playUnlock() => playSfx('unlock');
  Future<void> playUndo() => playSfx('erase');

  // ==========================================
  // WAV SYNTHESIS IMPLEMENTATION
  // ==========================================

  double _triangle(double phase) {
    double p = (phase % (2.0 * math.pi)) / (2.0 * math.pi); // 0.0 to 1.0
    if (p < 0.25) {
      return 4.0 * p;
    } else if (p < 0.75) {
      return 2.0 - 4.0 * p;
    } else {
      return 4.0 * p - 4.0;
    }
  }

  Uint8List _generateWavHeader(int dataSize, int sampleRate) {
    final header = ByteData(44);
    
    // "RIFF"
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    
    // File size - 8
    header.setUint32(4, 36 + dataSize, Endian.little);
    
    // "WAVE"
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    
    // "fmt "
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6d); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); //  
    
    // Chunk size = 16
    header.setUint32(16, 16, Endian.little);
    
    // Format = 1 (PCM)
    header.setUint16(20, 1, Endian.little);
    
    // Channels = 1 (Mono)
    header.setUint16(22, 1, Endian.little);
    
    // Sample rate
    header.setUint32(24, sampleRate, Endian.little);
    
    // Byte rate = SampleRate * Channels * BytesPerSample = sampleRate * 1 * 2
    header.setUint32(28, sampleRate * 2, Endian.little);
    
    // Block align = Channels * BytesPerSample = 2
    header.setUint16(32, 2, Endian.little);
    
    // Bits per sample = 16
    header.setUint16(34, 16, Endian.little);
    
    // "data"
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    
    // Data chunk size
    header.setUint32(40, dataSize, Endian.little);
    
    return header.buffer.asUint8List();
  }

  /// Move SFX: Triangle sweep (150Hz -> 50Hz) over 0.1s
  Uint8List _synthesizeMove(int sampleRate) {
    const double duration = 0.1;
    final int numSamples = (sampleRate * duration).toInt();
    final data = ByteData(numSamples * 2);
    
    double phase = 0.0;
    for (int i = 0; i < numSamples; i++) {
      final double progress = i / numSamples;
      final double freq = 150.0 * math.pow(50.0 / 150.0, progress);
      phase += (2.0 * math.pi * freq) / sampleRate;
      
      final double rawVal = _triangle(phase);
      final double gain = 0.25 - (0.25 - 0.01) * progress; // Linear decay
      
      final int sampleInt = (rawVal * gain * 32767.0).toInt().clamp(-32768, 32767);
      data.setInt16(i * 2, sampleInt, Endian.little);
    }
    
    final header = _generateWavHeader(data.lengthInBytes, sampleRate);
    final wavBytes = Uint8List(header.length + data.lengthInBytes);
    wavBytes.setRange(0, header.length, header);
    wavBytes.setRange(header.length, wavBytes.length, data.buffer.asUint8List());
    return wavBytes;
  }

  /// Rule Change SFX: Double high-pitch sine chirp (1200Hz then 1800Hz)
  Uint8List _synthesizeRuleChange(int sampleRate) {
    const double duration = 0.05;
    final int numSamples = (sampleRate * duration).toInt();
    final data = ByteData(numSamples * 2);
    
    double phase = 0.0;
    for (int i = 0; i < numSamples; i++) {
      final double progress = i / numSamples;
      final double time = progress * duration;
      final double freq = time < 0.02 ? 1200.0 : 1800.0;
      phase += (2.0 * math.pi * freq) / sampleRate;
      
      final double rawVal = math.sin(phase);
      final double gain = 0.12 - (0.12 - 0.01) * progress;
      
      final int sampleInt = (rawVal * gain * 32767.0).toInt().clamp(-32768, 32767);
      data.setInt16(i * 2, sampleInt, Endian.little);
    }
    
    final header = _generateWavHeader(data.lengthInBytes, sampleRate);
    final wavBytes = Uint8List(header.length + data.lengthInBytes);
    wavBytes.setRange(0, header.length, header);
    wavBytes.setRange(header.length, wavBytes.length, data.buffer.asUint8List());
    return wavBytes;
  }

  /// Merge SFX: Triangle sweep (220Hz -> 550Hz) over 0.25s
  Uint8List _synthesizeMerge(int sampleRate) {
    const double duration = 0.25;
    final int numSamples = (sampleRate * duration).toInt();
    final data = ByteData(numSamples * 2);
    
    double phase = 0.0;
    for (int i = 0; i < numSamples; i++) {
      final double progress = i / numSamples;
      final double freq = 220.0 * math.pow(550.0 / 220.0, progress);
      phase += (2.0 * math.pi * freq) / sampleRate;
      
      final double rawVal = _triangle(phase);
      final double gain = 0.20 * (1.0 - progress);
      
      final int sampleInt = (rawVal * gain * 32767.0).toInt().clamp(-32768, 32767);
      data.setInt16(i * 2, sampleInt, Endian.little);
    }
    
    final header = _generateWavHeader(data.lengthInBytes, sampleRate);
    final wavBytes = Uint8List(header.length + data.lengthInBytes);
    wavBytes.setRange(0, header.length, header);
    wavBytes.setRange(header.length, wavBytes.length, data.buffer.asUint8List());
    return wavBytes;
  }

  /// Erase/Undo SFX: Short sine drop chirp (400Hz -> 200Hz)
  Uint8List _synthesizeErase(int sampleRate) {
    const double duration = 0.08;
    final int numSamples = (sampleRate * duration).toInt();
    final data = ByteData(numSamples * 2);
    
    double phase = 0.0;
    for (int i = 0; i < numSamples; i++) {
      final double progress = i / numSamples;
      final double freq = 400.0 - (400.0 - 200.0) * progress;
      phase += (2.0 * math.pi * freq) / sampleRate;
      
      final double rawVal = math.sin(phase);
      final double gain = 0.12 * (1.0 - progress);
      
      final int sampleInt = (rawVal * gain * 32767.0).toInt().clamp(-32768, 32767);
      data.setInt16(i * 2, sampleInt, Endian.little);
    }
    
    final header = _generateWavHeader(data.lengthInBytes, sampleRate);
    final wavBytes = Uint8List(header.length + data.lengthInBytes);
    wavBytes.setRange(0, header.length, header);
    wavBytes.setRange(header.length, wavBytes.length, data.buffer.asUint8List());
    return wavBytes;
  }

  /// Unlock Gate SFX: Three consecutive bell tones (C5, E5, G5)
  Uint8List _synthesizeUnlock(int sampleRate) {
    const double duration = 0.42;
    final int numSamples = (sampleRate * duration).toInt();
    final data = ByteData(numSamples * 2);
    
    final double t1 = 0.0;
    final double t2 = 0.08;
    final double t3 = 0.16;
    const double toneDur = 0.25;
    
    double phase1 = 0.0;
    double phase2 = 0.0;
    double phase3 = 0.0;
    
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      double val = 0.0;
      
      // C5 Note
      if (t >= t1 && t < t1 + toneDur) {
        phase1 += (2.0 * math.pi * 523.25) / sampleRate;
        final double progress = (t - t1) / toneDur;
        final double gain = 0.12 * (1.0 - progress);
        val += math.sin(phase1) * gain;
      }
      
      // E5 Note
      if (t >= t2 && t < t2 + toneDur) {
        phase2 += (2.0 * math.pi * 659.25) / sampleRate;
        final double progress = (t - t2) / toneDur;
        final double gain = 0.12 * (1.0 - progress);
        val += math.sin(phase2) * gain;
      }
      
      // G5 Note
      if (t >= t3 && t < t3 + toneDur) {
        phase3 += (2.0 * math.pi * 783.99) / sampleRate;
        final double progress = (t - t3) / toneDur;
        final double gain = 0.12 * (1.0 - progress);
        val += math.sin(phase3) * gain;
      }
      
      final int sampleInt = (val * 32767.0).toInt().clamp(-32768, 32767);
      data.setInt16(i * 2, sampleInt, Endian.little);
    }
    
    final header = _generateWavHeader(data.lengthInBytes, sampleRate);
    final wavBytes = Uint8List(header.length + data.lengthInBytes);
    wavBytes.setRange(0, header.length, header);
    wavBytes.setRange(header.length, wavBytes.length, data.buffer.asUint8List());
    return wavBytes;
  }

  /// Death/Failure SFX: Glitchy descending sawtooth sweep modulated by LFO
  Uint8List _synthesizeFail(int sampleRate) {
    const double duration = 0.45;
    final int numSamples = (sampleRate * duration).toInt();
    final data = ByteData(numSamples * 2);
    
    double phase = 0.0;
    for (int i = 0; i < numSamples; i++) {
      final double progress = i / numSamples;
      final double time = progress * duration;
      
      final double baseFreq = 320.0 - (320.0 - 80.0) * progress;
      final double lfoVal = math.sin(2.0 * math.pi * 25.0 * time);
      final double freq = baseFreq + lfoVal * 30.0;
      phase += (2.0 * math.pi * freq) / sampleRate;
      
      final double p = (phase % (2.0 * math.pi)) / (2.0 * math.pi);
      final double rawVal = 2.0 * p - 1.0; // Sawtooth
      final double gain = 0.20 * (1.0 - progress);
      
      final int sampleInt = (rawVal * gain * 32767.0).toInt().clamp(-32768, 32767);
      data.setInt16(i * 2, sampleInt, Endian.little);
    }
    
    final header = _generateWavHeader(data.lengthInBytes, sampleRate);
    final wavBytes = Uint8List(header.length + data.lengthInBytes);
    wavBytes.setRange(0, header.length, header);
    wavBytes.setRange(header.length, wavBytes.length, data.buffer.asUint8List());
    return wavBytes;
  }

  /// Victory SFX: Rich major chord arpeggio
  Uint8List _synthesizeWin(int sampleRate) {
    const double duration = 0.85;
    final int numSamples = (sampleRate * duration).toInt();
    final data = ByteData(numSamples * 2);
    
    final List<double> freqs = [261.63, 329.63, 392.00, 523.25, 659.25, 783.99, 1046.50];
    const double noteDur = 0.35;
    final List<double> phases = List.filled(freqs.length, 0.0);
    
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      double val = 0.0;
      
      for (int n = 0; n < freqs.length; n++) {
        final double noteStart = n * 0.08;
        if (t >= noteStart && t < noteStart + noteDur) {
          phases[n] += (2.0 * math.pi * freqs[n]) / sampleRate;
          final double progress = (t - noteStart) / noteDur;
          
          final double rawVal = n % 2 == 0 ? math.sin(phases[n]) : _triangle(phases[n]);
          final double gain = 0.12 * (1.0 - progress);
          val += rawVal * gain;
        }
      }
      
      final int sampleInt = (val * 32767.0).toInt().clamp(-32768, 32767);
      data.setInt16(i * 2, sampleInt, Endian.little);
    }
    
    final header = _generateWavHeader(data.lengthInBytes, sampleRate);
    final wavBytes = Uint8List(header.length + data.lengthInBytes);
    wavBytes.setRange(0, header.length, header);
    wavBytes.setRange(header.length, wavBytes.length, data.buffer.asUint8List());
    return wavBytes;
  }
}
