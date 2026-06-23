import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rule_glyph_app/audio/audio_manager.dart';
import 'package:rule_glyph_app/data/levels_data.dart';
import 'package:rule_glyph_app/screens/game_screen.dart';
import 'package:rule_glyph_app/widgets/dpad.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('out of steps dialog resets the current level', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final wasMuted = AudioManager.instance.isMuted;
    AudioManager.instance.isMuted = true;
    final previousLevels = LEVELS_BY_MODE['dialog-test'];
    LEVELS_BY_MODE['dialog-test'] = [_oneStepLevel()];
    addTearDown(() {
      AudioManager.instance.isMuted = wasMuted;
      if (previousLevels == null) {
        LEVELS_BY_MODE.remove('dialog-test');
      } else {
        LEVELS_BY_MODE['dialog-test'] = previousLevels;
      }
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(0.5)),
          child: GameScreen(mode: 'dialog-test'),
        ),
      ),
    );

    _moveRight(tester);
    await tester.pumpAndSettle();

    expect(find.text('Batas Langkah Habis'), findsOneWidget);
    expect(find.text('Reset Level'), findsOneWidget);

    await tester.tap(find.text('Reset Level'));
    await tester.pumpAndSettle();
    expect(find.text('Batas Langkah Habis'), findsNothing);

    _moveRight(tester);
    await tester.pumpAndSettle();
    expect(find.text('Batas Langkah Habis'), findsOneWidget);
  });
}

void _moveRight(WidgetTester tester) {
  tester
      .widget<DPad>(find.byType(DPad))
      .onDirectionPressed(1, 0);
}

LevelData _oneStepLevel() {
  return LevelData(
    id: 1,
    name: 'Out of steps test',
    description: 'The first move consumes the only available step.',
    width: 5,
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
      '#####',
      '#@.X#',
      '#####',
    ],
  );
}
