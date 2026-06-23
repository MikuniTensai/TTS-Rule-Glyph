import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rule_glyph_app/data/levels_data.dart';
import 'package:rule_glyph_app/engine/game_engine.dart';
import 'package:rule_glyph_app/widgets/grid_board.dart';

const _onePixelPng =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAADUlEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

void main() {
  testWidgets('wall textures are decoded once and reused after player moves',
      (tester) async {
    final level = LevelData(
      id: 1,
      name: 'Texture cache test',
      description: 'Verifies that movement does not reload wall textures.',
      width: 4,
      height: 3,
      movesLimit: 2,
      initialRules: const {
        'red': 'STOP',
        'blue': 'STOP',
        'green': 'STOP',
      },
      allowedRules: const {
        'red': ['STOP'],
        'blue': ['STOP'],
        'green': ['STOP'],
      },
      map: const [
        '####',
        '#@X#',
        '####',
      ],
      customWall0: _onePixelPng,
    );
    final engine = GameEngine()..loadLevel(level);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GridBoard(engine: engine),
        ),
      ),
    );

    final firstProviders = _memoryImageProviders(tester);
    expect(firstProviders, hasLength(10));
    expect(firstProviders.every((image) => identical(image, firstProviders[0])),
        isTrue);
    expect(_texturedWallDecorations(tester).every((wall) => wall.border == null),
        isTrue);
    expect(
        _texturedWallDecorations(tester)
            .every((wall) => wall.boxShadow == null),
        isTrue);

    engine.tryMove(1, 0, START_RULES);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: GridBoard(engine: engine),
        ),
      ),
    );

    final movedProviders = _memoryImageProviders(tester);
    expect(movedProviders, hasLength(10));
    expect(identical(movedProviders[0], firstProviders[0]), isTrue);
  });

  testWidgets('floor texture state is replaced when the level changes',
      (tester) async {
    final firstLevel = _floorLevel(
      id: 1,
      texture: _onePixelPng,
    );
    final secondLevel = _floorLevel(
      id: 2,
      texture: _onePixelPng.substring(_onePixelPng.indexOf(',') + 1),
    );
    final engine = GameEngine()..loadLevel(firstLevel);

    await _pumpBoard(tester, engine);
    final firstState = tester.state(find.byType(GridBoard));
    final firstProvider = _memoryImageProviders(tester).single;

    engine.loadLevel(secondLevel);
    await _pumpBoard(tester, engine);

    expect(tester.state(find.byType(GridBoard)), isNot(same(firstState)));
    expect(_memoryImageProviders(tester).single, isNot(same(firstProvider)));
  });
}

LevelData _floorLevel({required int id, required String texture}) {
  return LevelData(
    id: id,
    name: 'Floor texture test $id',
    description: 'Verifies that a previous floor image is not retained.',
    width: 3,
    height: 3,
    movesLimit: 1,
    initialRules: const {
      'red': 'STOP',
      'blue': 'STOP',
      'green': 'STOP',
    },
    allowedRules: const {
      'red': ['STOP'],
      'blue': ['STOP'],
      'green': ['STOP'],
    },
    map: const [
      '###',
      '#@#',
      '###',
    ],
    customFloor: texture,
  );
}

Future<void> _pumpBoard(WidgetTester tester, GameEngine engine) {
  return tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: 400,
        height: 300,
        child: GridBoard(
          key: ObjectKey(engine.activeLevel),
          engine: engine,
        ),
      ),
    ),
  );
}

List<MemoryImage> _memoryImageProviders(WidgetTester tester) {
  return tester
      .widgetList<Container>(find.byType(Container))
      .map((container) => container.decoration)
      .whereType<BoxDecoration>()
      .map((decoration) => decoration.image?.image)
      .whereType<MemoryImage>()
      .toList();
}

List<BoxDecoration> _texturedWallDecorations(WidgetTester tester) {
  return tester
      .widgetList<Container>(find.byType(Container))
      .map((container) => container.decoration)
      .whereType<BoxDecoration>()
      .where((decoration) => decoration.image?.image is MemoryImage)
      .toList();
}
