import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('assets/levels.json');
  if (!file.existsSync()) {
    print('Error: assets/levels.json not found. Run bin/generate_json.dart first.');
    return;
  }

  final String content = file.readAsStringSync();
  final Map<String, dynamic> data = json.decode(content);

  // 1. Process Solo levels (levels_by_mode -> '1')
  final List<dynamic> soloList = data['levels_by_mode']['1'] ?? [];
  print('Total solo levels found: ${soloList.length}');

  // Distribute solo levels:
  // Chapter 1 has 22 levels (base levels 1-22).
  // Chapters 2-9 each have 12 levels.
  int currentSoloIdx = 0;
  
  // Chapter 1 (22 levels)
  _writeSoloChapter(1, soloList.sublist(0, 22));
  
  // Chapters 2-9 (12 levels each)
  for (int chap = 2; chap <= 9; chap++) {
    final int start = 22 + (chap - 2) * 12;
    final int end = start + 12;
    if (end <= soloList.length) {
      _writeSoloChapter(chap, soloList.sublist(start, end));
    }
  }

  // 2. Process Coop levels
  final Map<String, dynamic> modesData = data['levels_by_mode'] ?? {};
  for (final mode in ['2', '3', '4']) {
    final List<dynamic> modeList = modesData[mode] ?? [];
    print('Total coop $mode-player levels found: ${modeList.length}');
    _writeCoopMode(mode, modeList);
  }

  print('JSON split complete. You can delete assets/levels.json now if you want.');
}

void _writeSoloChapter(int chapNum, List<dynamic> levels) {
  final dir = Directory('assets/levels/solo/chap$chapNum');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  for (int i = 0; i < levels.length; i++) {
    final level = levels[i] as Map<String, dynamic>;
    final levelNumInChap = i + 1;
    final levelFile = File('${dir.path}/$levelNumInChap.json');
    
    // Convert back to structured JSON
    final jsonStr = const JsonEncoder.withIndent('  ').convert(level);
    levelFile.writeAsStringSync(jsonStr);
  }
  print('Wrote ${levels.length} levels to chap$chapNum');
}

void _writeCoopMode(String modeName, List<dynamic> levels) {
  final dir = Directory('assets/levels/coop/${modeName}p');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  for (int i = 0; i < levels.length; i++) {
    final level = levels[i] as Map<String, dynamic>;
    final levelNum = i + 1;
    final levelFile = File('${dir.path}/$levelNum.json');
    
    final jsonStr = const JsonEncoder.withIndent('  ').convert(level);
    levelFile.writeAsStringSync(jsonStr);
  }
  print('Wrote ${levels.length} levels to coop/${modeName}p');
}
