import 'dart:convert';
import 'dart:io';
import '../lib/data/levels_data.dart';

void main() {
  // Ensure assets directory exists
  final assetsDir = Directory('assets');
  if (!assetsDir.existsSync()) {
    assetsDir.createSync(recursive: true);
  }

  final Map<String, dynamic> data = {
    'base_levels': BASE_LEVELS.map((l) => l.toJson()).toList(),
    'levels_by_mode': {
      '1': LEVELS.map((l) => l.toJson()).toList(),
      '2': (LEVELS_BY_MODE['2'] ?? []).map((l) => l.toJson()).toList(),
      '3': (LEVELS_BY_MODE['3'] ?? []).map((l) => l.toJson()).toList(),
      '4': (LEVELS_BY_MODE['4'] ?? []).map((l) => l.toJson()).toList(),
    }
  };

  final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
  final file = File('assets/levels.json');
  file.writeAsStringSync(jsonStr);
  print('Successfully generated assets/levels.json');
}
