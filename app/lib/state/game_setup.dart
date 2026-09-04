import 'package:dart_scoring_core/dart_scoring_core.dart';

/// Which family of rules a new game uses.
enum GameModeType { x01, cricket, aroundTheClock }

/// Everything chosen on the "New game" screen, handed to
/// [GameController.startGame] to build the right [GameEngine].
class GameSetup {
  final GameModeType mode;
  final List<String> playerNames;

  // X01 ("倒扣") options.
  final int x01StartingScore;
  final X01OutMode x01OutMode;
  final X01InMode x01InMode;

  // Cricket ("占地盤") options.
  final CricketScoringMode cricketMode;

  // Around the Clock options.
  final bool atcRequireDouble;

  /// Whether the camera should try to auto-detect darts landing, versus
  /// the player confirming/entering every dart by hand.
  final bool autoDetectEnabled;

  const GameSetup({
    required this.mode,
    required this.playerNames,
    this.x01StartingScore = 501,
    this.x01OutMode = X01OutMode.doubleOut,
    this.x01InMode = X01InMode.straight,
    this.cricketMode = CricketScoringMode.standard,
    this.atcRequireDouble = false,
    this.autoDetectEnabled = false,
  });

  GameSetup copyWith({
    GameModeType? mode,
    List<String>? playerNames,
    int? x01StartingScore,
    X01OutMode? x01OutMode,
    X01InMode? x01InMode,
    CricketScoringMode? cricketMode,
    bool? atcRequireDouble,
    bool? autoDetectEnabled,
  }) {
    return GameSetup(
      mode: mode ?? this.mode,
      playerNames: playerNames ?? this.playerNames,
      x01StartingScore: x01StartingScore ?? this.x01StartingScore,
      x01OutMode: x01OutMode ?? this.x01OutMode,
      x01InMode: x01InMode ?? this.x01InMode,
      cricketMode: cricketMode ?? this.cricketMode,
      atcRequireDouble: atcRequireDouble ?? this.atcRequireDouble,
      autoDetectEnabled: autoDetectEnabled ?? this.autoDetectEnabled,
    );
  }
}
