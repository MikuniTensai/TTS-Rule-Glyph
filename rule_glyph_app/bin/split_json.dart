import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('assets/levels.json');
  if (!file.existsSync()) {
    print(
        'Error: assets/levels.json not found. Run bin/generate_json.dart first.');
    return;
  }

  final String content = file.readAsStringSync();
  final Map<String, dynamic> data = json.decode(content);
  final modesData = data['levels_by_mode'];
  if (modesData is! Map<String, dynamic>) {
    throw const FormatException('levels_by_mode is required');
  }

  // 1. Process Solo levels (levels_by_mode -> '1')
  final List<dynamic> soloList =
      List<dynamic>.from(modesData['1'] as List? ?? []);
  _validateLevels(soloList, '1');
  print('Total solo levels found: ${soloList.length}');

  // Distribute solo levels:
  // Chapter 1 has 22 levels (base levels 1-22).
  // Chapters 2-9 each have 12 levels.
  // Chapter 1 (22 levels)
  _writeSoloChapter(1, _safeSlice(soloList, 0, 22));

  // Chapters 2-9 (12 levels each)
  for (int chap = 2; chap <= 9; chap++) {
    final int start = 22 + (chap - 2) * 12;
    _writeSoloChapter(chap, _safeSlice(soloList, start, 12));
  }

  // 2. Process Coop levels
  for (final mode in ['2', '3', '4']) {
    final List<dynamic> modeList =
        List<dynamic>.from(modesData[mode] as List? ?? []);
    _validateLevels(modeList, mode);
    print('Total coop $mode-player levels found: ${modeList.length}');
    _writeCoopMode(mode, modeList);
  }

  print('JSON split complete. assets/levels.json remains the source of truth.');
}

List<dynamic> _safeSlice(List<dynamic> source, int start, int length) {
  if (start >= source.length) return [];
  final requestedEnd = start + length;
  final end = requestedEnd < source.length ? requestedEnd : source.length;
  return source.sublist(start, end);
}

void _validateLevels(List<dynamic> levels, String mode) {
  for (var index = 0; index < levels.length; index++) {
    final level = levels[index];
    if (level is! Map<String, dynamic>) {
      throw FormatException('Mode $mode level ${index + 1} is not an object');
    }
    final width = level['width'];
    final height = level['height'];
    final map = level['map'];
    if (width is! int ||
        height is! int ||
        map is! List ||
        map.length != height) {
      throw FormatException(
          'Mode $mode level ${index + 1} has invalid dimensions');
    }
    for (final row in map) {
      if (row is! String || row.length != width) {
        throw FormatException(
            'Mode $mode level ${index + 1} has an invalid row width');
      }
    }
  }
}

void _writeSoloChapter(int chapNum, List<dynamic> levels) {
  final dir = Directory('assets/levels/solo/chap$chapNum');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  _removeJsonFiles(dir);

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

  _removeJsonFiles(dir);

  for (int i = 0; i < levels.length; i++) {
    final level = levels[i] as Map<String, dynamic>;
    final levelNum = i + 1;
    final levelFile = File('${dir.path}/$levelNum.json');

    final jsonStr = const JsonEncoder.withIndent('  ').convert(level);
    levelFile.writeAsStringSync(jsonStr);
  }
  print('Wrote ${levels.length} levels to coop/${modeName}p');
}

void _removeJsonFiles(Directory dir) {
  for (final entry in dir.listSync()) {
    if (entry is File && entry.path.toLowerCase().endsWith('.json')) {
      entry.deleteSync();
    }
  }
}
