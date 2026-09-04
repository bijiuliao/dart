import '../board/dart_hit.dart';
import 'player.dart';
import 'recorded_throw.dart';

/// Result of a subclass applying its mode-specific scoring rules to a
/// single dart.
class ApplyResult {
  final int pointsScored;
  final bool bust;

  /// True if this dart just won the game for the throwing player.
  final bool endsGame;

  /// True if the engine wants the turn to end immediately even though
  /// fewer than 3 darts have been thrown (bust already implies this; this
  /// flag is for other mode-specific early-end cases).
  final bool forceEndTurn;

  final String? message;

  const ApplyResult({
    this.pointsScored = 0,
    this.bust = false,
    this.endsGame = false,
    this.forceEndTurn = false,
    this.message,
  });
}

/// What happened as a result of [GameEngine.recordThrow].
class ThrowOutcome {
  final RecordedThrow throwRecord;
  final bool turnEnded;
  final bool bust;
  final bool gameOver;
  final String? message;

  int get pointsScored => throwRecord.pointsScored;

  const ThrowOutcome({
    required this.throwRecord,
    required this.turnEnded,
    required this.bust,
    required this.gameOver,
    this.message,
  });
}

/// Common surface every game mode (X01, Cricket, Around the Clock, ...)
/// implements. The camera layer and the UI only need to talk to this
/// interface for the shared mechanics (whose turn it is, recording a
/// dart, undo); mode-specific state (remaining score, marks, ...) is
/// exposed via typed getters on the concrete engine classes.
abstract class GameEngine {
  List<Player> get players;
  int get currentPlayerIndex;
  Player get currentPlayer;
  int get currentTurnNumber;
  bool get isGameOver;
  Player? get winner;

  /// Darts thrown so far in the current turn (0-3), most recent last.
  List<RecordedThrow> get currentTurnThrows;

  /// Every dart thrown so far this game, in order.
  List<RecordedThrow> get history;

  /// Records one dart for the current player and applies this mode's
  /// scoring rules. Automatically advances to the next player once 3
  /// darts have been thrown in the turn, on a bust, or on a game-ending
  /// throw.
  ThrowOutcome recordThrow(DartHit hit, {bool autoDetected = false});

  /// Manually ends the current player's turn right now (e.g. the camera
  /// missed a dart, or the group wants to move on early) without scoring
  /// any more darts for it. A no-op once the game is over.
  void nextPlayer();

  /// Undoes the most recently recorded dart, restoring all state
  /// (including whose turn it is). Returns false if there is nothing to
  /// undo.
  bool undoLastThrow();
}

/// Shared bookkeeping (turn rotation, history, undo-via-snapshot) so each
/// game mode only has to implement its own scoring rules.
abstract class BaseGameEngine implements GameEngine {
  @override
  final List<Player> players;

  @override
  int currentPlayerIndex = 0;

  final List<RecordedThrow> _currentTurnThrows = [];
  final List<RecordedThrow> _history = [];
  final List<_Snapshot> _snapshots = [];

  int _turnNumber = 1;
  bool _gameOver = false;
  Player? _winner;

  BaseGameEngine(this.players) {
    if (players.isEmpty) {
      throw ArgumentError('A game needs at least one player');
    }
  }

  @override
  Player get currentPlayer => players[currentPlayerIndex];
  @override
  int get currentTurnNumber => _turnNumber;
  @override
  List<RecordedThrow> get currentTurnThrows =>
      List.unmodifiable(_currentTurnThrows);
  @override
  List<RecordedThrow> get history => List.unmodifiable(_history);
  @override
  bool get isGameOver => _gameOver;
  @override
  Player? get winner => _winner;

  /// Applies this mode's scoring rules for [player] hitting [hit].
  ApplyResult applyHit(Player player, DartHit hit);

  /// Deep-copies whatever mutable state this mode keeps (score maps,
  /// marks, ...) so it can be restored by [restoreState] on undo.
  Object captureState();
  void restoreState(Object state);

  @override
  ThrowOutcome recordThrow(DartHit hit, {bool autoDetected = false}) {
    if (_gameOver) {
      throw StateError('Cannot record a throw: the game is already over');
    }
    if (_currentTurnThrows.length >= 3) {
      throw StateError('This turn already has 3 darts recorded');
    }

    _snapshots.add(_Snapshot(
      state: captureState(),
      currentPlayerIndex: currentPlayerIndex,
      turnNumber: _turnNumber,
      currentTurnThrows: List.of(_currentTurnThrows),
      gameOver: _gameOver,
      winner: _winner,
    ));

    final player = currentPlayer;
    final result = applyHit(player, hit);

    final recorded = RecordedThrow(
      playerId: player.id,
      hit: hit,
      turnNumber: _turnNumber,
      dartIndexInTurn: _currentTurnThrows.length,
      pointsScored: result.pointsScored,
      autoDetected: autoDetected,
      wasBust: result.bust,
    );
    _currentTurnThrows.add(recorded);
    _history.add(recorded);

    if (result.endsGame) {
      _gameOver = true;
      _winner = player;
    }

    final turnEnded = result.bust ||
        result.forceEndTurn ||
        _currentTurnThrows.length >= 3 ||
        _gameOver;

    if (turnEnded && !_gameOver) {
      _startNextTurn();
    }

    return ThrowOutcome(
      throwRecord: recorded,
      turnEnded: turnEnded,
      bust: result.bust,
      gameOver: _gameOver,
      message: result.message,
    );
  }

  void _startNextTurn() {
    _currentTurnThrows.clear();
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    _turnNumber++;
  }

  @override
  void nextPlayer() {
    if (_gameOver) return;
    _startNextTurn();
  }

  @override
  bool undoLastThrow() {
    if (_snapshots.isEmpty) return false;
    final snap = _snapshots.removeLast();
    restoreState(snap.state);
    currentPlayerIndex = snap.currentPlayerIndex;
    _turnNumber = snap.turnNumber;
    _currentTurnThrows
      ..clear()
      ..addAll(snap.currentTurnThrows);
    _gameOver = snap.gameOver;
    _winner = snap.winner;
    if (_history.isNotEmpty) _history.removeLast();
    return true;
  }
}

class _Snapshot {
  final Object state;
  final int currentPlayerIndex;
  final int turnNumber;
  final List<RecordedThrow> currentTurnThrows;
  final bool gameOver;
  final Player? winner;

  _Snapshot({
    required this.state,
    required this.currentPlayerIndex,
    required this.turnNumber,
    required this.currentTurnThrows,
    required this.gameOver,
    required this.winner,
  });
}
