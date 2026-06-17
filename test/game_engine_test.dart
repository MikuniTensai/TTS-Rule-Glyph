import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rule_glyph_app/data/levels_data.dart';
import 'package:rule_glyph_app/engine/game_engine.dart';

void main() {
  group('GameEngine Logic Tests', () {
    late GameEngine engine;

    setUp(() {
      engine = GameEngine();
    });

    test('Load First Level - Verify Player and Portal Position', () {
      final level1 = BASE_LEVELS[0]; // Steps limit = 3, map has player at row 2 col 2
      engine.loadLevel(level1);

      expect(engine.width, equals(5));
      expect(engine.height, equals(5));

      final p1 = engine.getPlayer('p1');
      expect(p1.x, equals(1));
      expect(p1.y, equals(1));

      expect(engine.cells[3][1].hasPortal, isTrue);
    });

    test('Move Player - Wall Blocking Check', () {
      final level1 = BASE_LEVELS[0];
      engine.loadLevel(level1);

      // Attempt to move UP into a Wall (row 0 is wall)
      final res = engine.tryMove(0, -1, START_RULES);
      expect(res.moved, isFalse);
      
      final p1 = engine.getPlayer('p1');
      expect(p1.x, equals(1));
      expect(p1.y, equals(1));
    });

    test('Move Player - Path to Victory', () {
      final level1 = BASE_LEVELS[0];
      engine.loadLevel(level1);

      // Move right (1,1) -> (2,1)
      var res = engine.tryMove(1, 0, START_RULES);
      expect(res.moved, isTrue);
      expect(res.won, isFalse);

      // Move right again (2,1) -> (3,1) (portal tile)
      res = engine.tryMove(1, 0, START_RULES);
      expect(res.moved, isTrue);
      expect(res.won, isTrue); // Portal reached and solo win triggers!
    });

    test('Pushing a glyph off a spike leaves the player dead on the uncovered spike', () {
      final level = LevelData(
        id: 9001,
        name: 'Spike regression',
        description: 'A glyph starts on a spike and is pushed away.',
        width: 5,
        height: 3,
        movesLimit: 1,
        initialRules: {'red': 'PUSH', 'blue': 'STOP', 'green': 'STOP'},
        allowedRules: {'red': ['PUSH'], 'blue': STOP_ONLY, 'green': STOP_ONLY},
        map: [
          '#####',
          '#@^.#',
          '#####',
        ],
      );

      engine.loadLevel(level);
      engine.spawnGlyph('red', 2, 1);

      final res = engine.tryMove(1, 0, level.initialRules);

      expect(res.moved, isTrue);
      expect(res.dead, isTrue);
      expect(res.deadPlayerIds, contains('p1'));
      expect(engine.getPlayer('p1').dead, isTrue);
    });

    test('Laser deaths report every dead player, not only the mover', () {
      final level = LevelData(
        id: 9002,
        name: 'Laser regression',
        description: 'P2 is placed in a laser path before P1 moves.',
        width: 5,
        height: 5,
        movesLimit: 1,
        initialRules: START_RULES,
        allowedRules: {'red': STOP_ONLY, 'blue': STOP_ONLY, 'green': STOP_ONLY},
        map: [
          '#####',
          '#@..#',
          '#L..#',
          '#...#',
          '#####',
        ],
      );

      engine.loadLevel(level);
      final p2 = engine.getPlayer('p2');
      p2.x = 2;
      p2.y = 2;

      final res = engine.tryMove(1, 0, START_RULES);

      expect(res.dead, isTrue);
      expect(res.deadPlayerIds, contains('p2'));
      expect(res.won, isFalse);
      expect(p2.dead, isTrue);
    });

    test('Vertical lasers keep vertical render metadata', () {
      final level = LevelData(
        id: 9003,
        name: 'Vertical laser',
        description: 'A vertical emitter creates vertical beams.',
        width: 5,
        height: 5,
        movesLimit: 1,
        initialRules: START_RULES,
        allowedRules: {'red': STOP_ONLY, 'blue': STOP_ONLY, 'green': STOP_ONLY},
        map: [
          '#####',
          '#...#',
          '#.l.#',
          '#...#',
          '#####',
        ],
      );

      engine.loadLevel(level);

      expect(engine.activeLaserBeams, contains('2,1'));
      expect(engine.activeLaserBeams, contains('2,3'));
      expect(engine.activeLaserBeamAxes['2,1'], equals('vertical'));
      expect(engine.activeLaserBeamAxes['2,3'], equals('vertical'));
    });

    test('Compiled level dimensions match map rows', () {
      for (final entry in LEVELS_BY_MODE.entries) {
        for (final level in entry.value) {
          expect(level.map.length, level.height, reason: 'mode ${entry.key} level ${level.id}');
          for (final row in level.map) {
            expect(row.length, level.width, reason: 'mode ${entry.key} level ${level.id}: $row');
          }
        }
      }
    });

    test('Asset level JSON dimensions match map rows', () {
      final levelFiles = Directory('assets/levels')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'));

      for (final file in levelFiles) {
        final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final width = data['width'] as int;
        final height = data['height'] as int;
        final map = List<String>.from(data['map'] as Iterable);

        expect(map.length, height, reason: file.path);
        for (final row in map) {
          expect(row.length, width, reason: '${file.path}: $row');
        }
      }
    });
  });
}
