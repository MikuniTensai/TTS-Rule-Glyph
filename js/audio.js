/**
 * Procedural Audio Synthesizer for Rule Glyph Lab
 * Uses Web Audio API to create retro game sounds dynamically.
 */

let audioCtx = null;
let isMuted = false;
try {
  isMuted = localStorage.getItem('rule_glyph_muted') === 'true';
} catch (e) {
  console.warn("localStorage is not accessible", e);
}

// Lazy-initialization of AudioContext to satisfy browser autoplay policies
function getAudioContext() {
  if (!audioCtx) {
    // Standard and vendor-prefixed support
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  }
  if (audioCtx.state === 'suspended') {
    audioCtx.resume();
  }
  return audioCtx;
}

export const AudioEngine = {
  isMuted() {
    return isMuted;
  },

  toggleMute() {
    isMuted = !isMuted;
    try {
      localStorage.setItem('rule_glyph_muted', isMuted);
    } catch (e) {}
    
    // Resume context if muting is disabled
    if (!isMuted) {
      getAudioContext();
    }
    return isMuted;
  },

  /**
   * Play a short low-frequency thump for movements
   */
  playMove() {
    if (isMuted) return;
    try {
      const ctx = getAudioContext();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'triangle';
      
      // Frequency sweep (150Hz -> 50Hz)
      const now = ctx.currentTime;
      osc.frequency.setValueAtTime(150, now);
      osc.frequency.exponentialRampToValueAtTime(50, now + 0.1);

      // Volume envelope (instant attack, quick decay)
      gain.gain.setValueAtTime(0.3, now);
      gain.gain.linearRampToValueAtTime(0.01, now + 0.1);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.1);
    } catch (e) {
      console.warn("Audio failed to play", e);
    }
  },

  /**
   * Play a crisp digital click for rule changes
   */
  playRuleChange() {
    if (isMuted) return;
    try {
      const ctx = getAudioContext();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'sine';
      
      const now = ctx.currentTime;
      // High pitch double-chirp
      osc.frequency.setValueAtTime(1200, now);
      osc.frequency.setValueAtTime(1800, now + 0.02);

      gain.gain.setValueAtTime(0.15, now);
      gain.gain.linearRampToValueAtTime(0.01, now + 0.05);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + 0.05);
    } catch (e) {
      console.warn("Audio failed to play", e);
    }
  },

  /**
   * Play a slide-up tone when two glyphs merge
   */
  playMerge() {
    if (isMuted) return;
    try {
      const ctx = getAudioContext();
      const oscNode = ctx.createOscillator();
      const gainNode = ctx.createGain();

      oscNode.type = 'triangle';
      
      const now = ctx.currentTime;
      // Frequency slide (200Hz -> 500Hz)
      oscNode.frequency.setValueAtTime(220, now);
      oscNode.frequency.exponentialRampToValueAtTime(550, now + 0.2);

      gainNode.gain.setValueAtTime(0.25, now);
      gainNode.gain.linearRampToValueAtTime(0.01, now + 0.22);

      oscNode.connect(gainNode);
      gainNode.connect(ctx.destination);

      oscNode.start(now);
      oscNode.stop(now + 0.25);
    } catch (e) {
      console.warn("Audio failed to play", e);
    }
  },

  /**
   * Play a mechanical slide-chime when a door opens
   */
  playUnlock() {
    if (isMuted) return;
    try {
      const ctx = getAudioContext();
      const now = ctx.currentTime;

      // Two consecutive clean bell-like tones
      const tones = [523.25, 659.25, 783.99]; // C5, E5, G5
      tones.forEach((freq, idx) => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        
        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, now + idx * 0.08);
        
        gain.gain.setValueAtTime(0, now + idx * 0.08);
        gain.gain.linearRampToValueAtTime(0.15, now + idx * 0.08 + 0.01);
        gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.08 + 0.2);
        
        osc.connect(gain);
        gain.connect(ctx.destination);
        
        osc.start(now + idx * 0.08);
        osc.stop(now + idx * 0.08 + 0.25);
      });
    } catch (e) {
      console.warn("Audio failed to play", e);
    }
  },

  /**
   * Play a glitchy descending buzz for out-of-moves/death
   */
  playFail() {
    if (isMuted) return;
    try {
      const ctx = getAudioContext();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'sawtooth';
      
      const now = ctx.currentTime;
      // Frequency plunge (350Hz -> 80Hz)
      osc.frequency.setValueAtTime(320, now);
      osc.frequency.linearRampToValueAtTime(80, now + 0.4);

      // Low frequency modulation (vibrato) for glitchy feel
      const lfo = ctx.createOscillator();
      const lfoGain = ctx.createGain();
      lfo.frequency.value = 25; // 25Hz vibrato
      lfoGain.gain.value = 30; // pitch variation range
      
      lfo.connect(lfoGain);
      lfoGain.connect(osc.frequency);
      
      gain.gain.setValueAtTime(0.3, now);
      gain.gain.linearRampToValueAtTime(0.01, now + 0.45);

      osc.connect(gain);
      gain.connect(ctx.destination);

      lfo.start(now);
      osc.start(now);
      
      lfo.stop(now + 0.45);
      osc.stop(now + 0.45);
    } catch (e) {
      console.warn("Audio failed to play", e);
    }
  },

  /**
   * Play a triumphant synth arpeggio for level complete
   */
  playWin() {
    if (isMuted) return;
    try {
      const ctx = getAudioContext();
      const now = ctx.currentTime;

      // Major chord arpeggio (C4 -> E4 -> G4 -> C5 -> E5 -> G5)
      const notes = [261.63, 329.63, 392.00, 523.25, 659.25, 783.99, 1046.50];
      notes.forEach((freq, idx) => {
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();

        // Alternate waves to create a richer texture
        osc.type = idx % 2 === 0 ? 'sine' : 'triangle';
        osc.frequency.setValueAtTime(freq, now + idx * 0.08);

        gain.gain.setValueAtTime(0, now + idx * 0.08);
        gain.gain.linearRampToValueAtTime(0.2, now + idx * 0.08 + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.08 + 0.35);

        osc.connect(gain);
        gain.connect(ctx.destination);

        osc.start(now + idx * 0.08);
        osc.stop(now + idx * 0.08 + 0.4);
      });
    } catch (e) {
      console.warn("Audio failed to play", e);
    }
  }
};
