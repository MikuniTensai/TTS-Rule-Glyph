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
      final level1 =
          BASE_LEVELS[0]; // Steps limit = 3, map has player at row 2 col 2
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

    test(
        'Pushing a glyph off a spike leaves the player dead on the uncovered spike',
        () {
      final level = LevelData(
        id: 9001,
        name: 'Spike regression',
        description: 'A glyph starts on a spike and is pushed away.',
        width: 5,
        height: 3,
        movesLimit: 1,
        initialRules: {'red': 'PUSH', 'blue': 'STOP', 'green': 'STOP'},
        allowedRules: {
          'red': ['PUSH'],
          'blue': STOP_ONLY,
          'green': STOP_ONLY
        },
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

    group('Wall challenge mechanics', () {
      LevelData levelFor({
        required int id,
        required List<String> map,
        Map<String, String>? rules,
      }) {
        return LevelData(
          id: id,
          name: 'Wall challenge $id',
          description: 'Focused wall challenge regression.',
          width: map.first.length,
          height: map.length,
          movesLimit: 8,
          initialRules: rules ?? START_RULES,
          allowedRules: {
            'red': ['STOP', 'PUSH', 'SWAP', 'MERGE'],
            'blue': ['STOP', 'PUSH', 'SWAP', 'MERGE'],
            'green': ['STOP', 'PUSH', 'SWAP', 'MERGE'],
          },
          map: map,
        );
      }

      test('cracked walls break when a glyph is pushed into them', () {
        final level = levelFor(
          id: 9101,
          rules: {'red': 'PUSH', 'blue': 'STOP', 'green': 'STOP'},
          map: [
            '######',
            '#@AR.#',
            '######',
          ],
        );

        engine.loadLevel(level);
        final res = engine.tryMove(1, 0, level.initialRules);

        expect(res.moved, isTrue);
        expect(engine.cells[3][1].isCrackedWall, isFalse);
        expect(engine.glyphs.singleWhere((g) => g.type == 'red').x, equals(3));
      });

      test('one-way walls only allow entry from their arrow direction', () {
        final allowLevel = levelFor(
          id: 9102,
          map: [
            '#####',
            '#@>.#',
            '#####',
          ],
        );
        engine.loadLevel(allowLevel);
        expect(engine.tryMove(1, 0, allowLevel.initialRules).moved, isTrue);

        final blockLevel = levelFor(
          id: 9103,
          map: [
            '#####',
            '#.>@#',
            '#####',
          ],
        );
        engine.loadLevel(blockLevel);
        expect(engine.tryMove(-1, 0, blockLevel.initialRules).moved, isFalse);
      });

      test('timed walls and linked walls alternate with step count', () {
        final timedLevel = levelFor(
          id: 9104,
          map: [
            '#####',
            '#@T.#',
            '#####',
          ],
        );
        engine.loadLevel(timedLevel);
        expect(engine.tryMove(1, 0, timedLevel.initialRules).moved, isFalse);
        engine.stepCount = 2;
        expect(engine.tryMove(1, 0, timedLevel.initialRules).moved, isTrue);

        final linkedALevel = levelFor(
          id: 9105,
          map: [
            '#####',
            '#@Y.#',
            '#####',
          ],
        );
        engine.loadLevel(linkedALevel);
        expect(engine.tryMove(1, 0, linkedALevel.initialRules).moved, isFalse);

        final linkedBLevel = levelFor(
          id: 9106,
          map: [
            '#####',
            '#@Z.#',
            '#####',
          ],
        );
        engine.loadLevel(linkedBLevel);
        expect(engine.tryMove(1, 0, linkedBLevel.initialRules).moved, isTrue);
      });

      test('color walls open when their color rule is not STOP', () {
        final level = levelFor(
          id: 9107,
          map: [
            '#####',
            '#@4.#',
            '#####',
          ],
        );

        engine.loadLevel(level);
        expect(
            engine.tryMove(
                1, 0, {'red': 'STOP', 'blue': 'STOP', 'green': 'STOP'}).moved,
            isFalse);
        engine.loadLevel(level);
        expect(
            engine.tryMove(
                1, 0, {'red': 'PUSH', 'blue': 'STOP', 'green': 'STOP'}).moved,
            isTrue);
      });

      test('mirror walls bounce players backward', () {
        final level = levelFor(
          id: 9108,
          map: [
            '######',
            '#.@M.#',
            '######',
          ],
        );

        engine.loadLevel(level);
        final res = engine.tryMove(1, 0, level.initialRules);

        expect(res.moved, isTrue);
        expect(engine.getPlayer('p1').x, equals(1));
        expect(engine.getPlayer('p1').y, equals(1));
      });

      test('soft walls cost two moves', () {
        final level = levelFor(
          id: 9109,
          map: [
            '#####',
            '#@W.#',
            '#####',
          ],
        );

        engine.loadLevel(level);
        final res = engine.tryMove(1, 0, level.initialRules);

        expect(res.moved, isTrue);
        expect(res.moveCost, equals(2));
      });

      test('rotating walls block only on their active axis', () {
        final verticalLevel = levelFor(
          id: 9110,
          map: [
            '#####',
            '#@|.#',
            '#####',
          ],
        );
        engine.loadLevel(verticalLevel);
        expect(engine.tryMove(1, 0, verticalLevel.initialRules).moved, isFalse);

        final horizontalLevel = levelFor(
          id: 9111,
          map: [
            '#####',
            '#@-.#',
            '#####',
          ],
        );
        engine.loadLevel(horizontalLevel);
        expect(
            engine.tryMove(1, 0, horizontalLevel.initialRules).moved, isTrue);
      });

      test('player-specific walls only allow their matching player', () {
        final p1Level = levelFor(
          id: 9112,
          map: [
            '#####',
            '#@Q.#',
            '#####',
          ],
        );
        engine.loadLevel(p1Level);
        expect(engine.tryMove(1, 0, p1Level.initialRules, playerId: 'p1').moved,
            isTrue);

        final p2Level = levelFor(
          id: 9113,
          map: [
            '#####',
            '#%Q.#',
            '#####',
          ],
        );
        engine.loadLevel(p2Level);
        expect(engine.tryMove(1, 0, p2Level.initialRules, playerId: 'p2').moved,
            isFalse);
      });

      test('glyph-only walls block players but allow pushed glyphs', () {
        final playerLevel = levelFor(
          id: 9114,
          map: [
            '#####',
            '#@D.#',
            '#####',
          ],
        );
        engine.loadLevel(playerLevel);
        expect(engine.tryMove(1, 0, playerLevel.initialRules).moved, isFalse);

        final glyphLevel = levelFor(
          id: 9115,
          rules: {'red': 'PUSH', 'blue': 'STOP', 'green': 'STOP'},
          map: [
            '#####',
            '#@AD#',
            '#####',
          ],
        );
        engine.loadLevel(glyphLevel);
        final res = engine.tryMove(1, 0, glyphLevel.initialRules);

        expect(res.moved, isTrue);
        expect(engine.glyphs.singleWhere((g) => g.type == 'red').x, equals(3));
      });
    });

    test('Compiled level dimensions match map rows', () {
      for (final entry in LEVELS_BY_MODE.entries) {
        for (final level in entry.value) {
          expect(level.map.length, level.height,
              reason: 'mode ${entry.key} level ${level.id}');
          for (final row in level.map) {
            expect(row.length, level.width,
                reason: 'mode ${entry.key} level ${level.id}: $row');
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
        final data =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final width = data['width'] as int;
        final height = data['height'] as int;
        final map = List<String>.from(data['map'] as Iterable);

        expect(map.length, height, reason: file.path);
        for (final row in map) {
          expect(row.length, width, reason: '${file.path}: $row');
        }
      }
    });

    test('Aggregate campaign JSON is valid and split assets stay synchronized',
        () {
      final campaign = jsonDecode(File('assets/levels.json').readAsStringSync())
          as Map<String, dynamic>;
      final modes =
          Map<String, dynamic>.from(campaign['levels_by_mode'] as Map);
      const playerSymbols = [
        ['@'],
        ['%', '&'],
        ['*'],
        ['\$'],
      ];
      const playerPortals = ['I', 'O', 'U', 'V'];

      for (final mode in ['1', '2', '3', '4']) {
        final rawLevels = List<dynamic>.from(modes[mode] as List);
        expect(rawLevels, isNotEmpty, reason: 'mode $mode');
        final ids = <int>{};

        for (var index = 0; index < rawLevels.length; index++) {
          final raw = Map<String, dynamic>.from(rawLevels[index] as Map);
          final level = LevelData.fromJson(raw);
          expect(ids.add(level.id), isTrue,
              reason: 'duplicate id ${level.id} in mode $mode');

          final mapText = level.map.join();
          for (var playerIndex = 0;
              playerIndex < playerSymbols.length;
              playerIndex++) {
            final count = playerSymbols[playerIndex].fold<int>(
                0, (sum, symbol) => sum + symbol.allMatches(mapText).length);
            final expected = playerIndex < int.parse(mode) ? 1 : 0;
            expect(count, expected,
                reason: 'mode $mode level ${level.id} P${playerIndex + 1}');
            if (expected == 1) {
              expect(
                mapText.contains('X') ||
                    mapText.contains(playerPortals[playerIndex]),
                isTrue,
                reason:
                    'mode $mode level ${level.id} has no P${playerIndex + 1} goal',
              );
            }
          }

          final splitPath = mode == '1'
              ? _soloSplitPath(index, rawLevels.length, List<dynamic>.from(campaign['chapters'] as Iterable).length)
              : 'assets/levels/coop/${mode}p/${index + 1}.json';
          final split = jsonDecode(File(splitPath).readAsStringSync());
          expect(split, equals(raw), reason: splitPath);
        }
      }

      final solo = List<dynamic>.from(modes['1'] as List);
      final base = List<dynamic>.from(campaign['base_levels'] as List);
      expect(base, equals(solo.take(22).toList()));
    });

    test('LevelData rejects unsupported map symbols', () {
      expect(
        () => LevelData.fromJson({
          'id': 9999,
          'name': 'Invalid symbol',
          'description': 'Validator regression.',
          'width': 3,
          'height': 3,
          'movesLimit': 3,
          'initialRules': START_RULES,
          'allowedRules': {
            'red': STOP_ONLY,
            'blue': STOP_ONLY,
            'green': STOP_ONLY,
          },
          'map': ['###', '#zX', '###'],
        }),
        throwsFormatException,
      );
    });
  });
}

String _soloSplitPath(int zeroBasedIndex, int totalLevels, int chaptersCount) {
  for (var chap = 1; chap <= chaptersCount; chap++) {
    final start = chap == 1 ? 0 : 22 + (chap - 2) * 12;
    final length = chap == 1 ? 22 : 12;
    final end = start + length;
    final safeEnd = chap == chaptersCount ? totalLevels : (end > totalLevels ? totalLevels : end);
    if (zeroBasedIndex >= start && zeroBasedIndex < safeEnd) {
      final levelInChapter = 1 + (zeroBasedIndex - start);
      return 'assets/levels/solo/chap$chap/$levelInChapter.json';
    }
  }
  return '';
}
