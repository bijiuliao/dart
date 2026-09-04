import 'package:dart_scoring_core/dart_scoring_core.dart';
import 'package:flutter/foundation.dart';

import 'game_setup.dart';

/// App-level state: the active [GameEngine] (if any), the camera
/// calibration, and whether the camera should try to auto-detect darts.
/// Screens read this via `context.watch<GameController>()` /
/// `context.read<GameController>()` (see main.dart's ChangeNotifierProvider).
class GameController extends ChangeNotifier {
  GameEngine? _engine;
  GameSetup? _setup;
  Homography? _calibration;
  bool autoDetectEnabled = false;
  String? _lastMessage;

  GameEngine? get engine => _engine;
  GameSetup? get setup => _setup;
  Homography? get calibration => _calibration;
  bool get isCalibrated => _calibration != null;
  bool get hasActiveGame => _engine != null;
  String? get lastMessage => _lastMessage;

  X01Engine? get x01 => _engine is X01Engine ? _engine as X01Engine : null;
  CricketEngine? get cricket =>
      _engine is CricketEngine ? _engine as CricketEngine : null;
  AroundTheClockEngine? get atc =>
      _engine is AroundTheClockEngine ? _engine as AroundTheClockEngine : null;

  void startGame(GameSetup setup) {
    _setup = setup;
    autoDetectEnabled = setup.autoDetectEnabled;

    final players = [
      for (var i = 0; i < setup.playerNames.length; i++)
        Player(
          id: 'p$i',
          name: setup.playerNames[i].trim().isEmpty
              ? 'Player ${i + 1}'
              : setup.playerNames[i].trim(),
        ),
    ];

    switch (setup.mode) {
      case GameModeType.x01:
        _engine = X01Engine(
          players: players,
          startingScore: setup.x01StartingScore,
          outMode: setup.x01OutMode,
          inMode: setup.x01InMode,
        );
      case GameModeType.cricket:
        _engine = CricketEngine(players: players, scoringMode: setup.cricketMode);
      case GameModeType.aroundTheClock:
        _engine = AroundTheClockEngine(
          players: players,
          requireDouble: setup.atcRequireDouble,
        );
    }
    _lastMessage = null;
    notifyListeners();
  }

  void setCalibration(Homography h) {
    _calibration = h;
    notifyListeners();
  }

  void clearCalibration() {
    _calibration = null;
    notifyListeners();
  }

  void setAutoDetect(bool enabled) {
    autoDetectEnabled = enabled;
    notifyListeners();
  }

  /// Records a dart already resolved to a [DartHit] — e.g. from the
  /// manual dartboard-tap widget or the numeric entry pad.
  ThrowOutcome? recordHit(DartHit hit, {required bool autoDetected}) {
    final engine = _engine;
    if (engine == null || engine.isGameOver) return null;
    final outcome = engine.recordThrow(hit, autoDetected: autoDetected);
    _lastMessage = outcome.message;
    notifyListeners();
    return outcome;
  }

  /// Records a dart located as a raw camera-image pixel — either tapped
  /// by the player on the live preview or found by the auto-detector —
  /// by mapping it through the calibration homography first.
  ThrowOutcome? recordImagePoint(Point2D imagePixel, {required bool autoDetected}) {
    final calibration = _calibration;
    if (calibration == null) return null;
    final boardPoint = calibration.applyInverse(imagePixel);
    final hit = BoardGeometry.hitForBoardPoint(boardPoint);
    return recordHit(hit, autoDetected: autoDetected);
  }

  void undo() {
    if (_engine?.undoLastThrow() ?? false) {
      _lastMessage = null;
      notifyListeners();
    }
  }

  void nextPlayer() {
    _engine?.nextPlayer();
    _lastMessage = null;
    notifyListeners();
  }

  void endGame() {
    _engine = null;
    _setup = null;
    _lastMessage = null;
    notifyListeners();
  }
}
