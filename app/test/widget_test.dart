// Basic smoke tests for the dart-scoring app.
//
// The real camera plugin has no implementation to talk to in a plain
// `flutter test` run (there's no device), and empirically its calls just
// hang rather than failing fast — so these tests avoid exercising the
// screens that call `availableCameras()`/`CameraController` directly, and
// instead cover the parts that matter most without a camera: navigating
// into the setup flow, and the fully manual (camera-less) scoring path,
// which is exactly what a player gets after skipping calibration.

import 'package:dart_scoring_app/app.dart';
import 'package:dart_scoring_app/screens/scoring_screen.dart';
import 'package:dart_scoring_app/state/game_controller.dart';
import 'package:dart_scoring_app/state/game_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('home screen shows the start-new-game entry point', (tester) async {
    await tester.pumpWidget(const DartScoringApp());
    await tester.pumpAndSettle();

    expect(find.text('開始新遊戲'), findsOneWidget);
  });

  testWidgets('new game screen leads into calibration', (tester) async {
    await tester.pumpWidget(const DartScoringApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('開始新遊戲'));
    await tester.pumpAndSettle();
    expect(find.text('新遊戲'), findsOneWidget); // NewGameScreen's AppBar title

    final nextButton = find.text('下一步：校準相機');
    await tester.scrollUntilVisible(nextButton, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(nextButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // let the push transition render

    expect(find.text('校準相機'), findsOneWidget); // CalibrationScreen's AppBar title
  });

  testWidgets(
      'skipping calibration reaches a fully manual scoring screen and records a hit',
      (tester) async {
    // Builds the controller with a game already started (as
    // NewGameScreen would) and calibration left unset (as if the player
    // tapped "略過校準，改用手動計分") — this drives exactly the same
    // ScoringScreen code path without needing the real camera plugin.
    final controller = GameController()
      ..startGame(const GameSetup(mode: GameModeType.x01, playerNames: ['Alice', 'Bob']));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: ScoringScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('501'), findsNWidgets(2));

    final dartboard = find.byKey(const ValueKey('dartboardTapTarget'));
    expect(dartboard, findsOneWidget);
    await tester.tapAt(tester.getCenter(dartboard)); // dead centre = bullseye (50)
    await tester.pumpAndSettle();

    expect(find.text('451'), findsOneWidget); // Alice: 501 - 50
    expect(find.text('501'), findsOneWidget); // Bob: untouched, still up next turn
  });
}
