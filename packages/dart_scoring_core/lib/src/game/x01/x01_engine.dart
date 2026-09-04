import '../../board/dart_hit.dart';
import '../game_engine.dart';
import '../player.dart';

/// How a leg must be finished.
enum X01OutMode { straight, doubleOut, masterOut }

/// How a leg must be started (some house rules require "getting in" on a
/// double or a double/triple before darts count).
enum X01InMode { straight, doubleIn, masterIn }

/// "倒扣" count-down games: 301 / 501 / 701 / custom starting score, with
/// configurable in/out rules and standard bust handling.
///
/// Bust rule (WDF standard): a throw busts if it would take the player's
/// remaining score below zero, to exactly 1 while a double (or double/
/// triple for master-out) is required to finish, or to exactly zero
/// without the finishing dart satisfying the required double/master. On a
/// bust, the whole turn is voided and the score reverts to what it was
/// before the turn started; the turn ends immediately even if darts
/// remain.
class X01Engine extends BaseGameEngine {
  final int startingScore;
  final X01OutMode outMode;
  final X01InMode inMode;

  final Map<String, int> _remaining = {};
  final Map<String, bool> _opened = {};
  final Map<String, int> _scoreAtTurnStart = {};

  X01Engine({
    required List<Player> players,
    this.startingScore = 501,
    this.outMode = X01OutMode.doubleOut,
    this.inMode = X01InMode.straight,
  }) : super(players) {
    for (final p in players) {
      _remaining[p.id] = startingScore;
      _opened[p.id] = inMode == X01InMode.straight;
      _scoreAtTurnStart[p.id] = startingScore;
    }
  }

  int remainingScore(String playerId) => _remaining[playerId] ?? startingScore;
  bool hasOpened(String playerId) => _opened[playerId] ?? true;

  bool _satisfiesIn(DartHit hit) => switch (inMode) {
        X01InMode.straight => true,
        X01InMode.doubleIn => hit.countsAsDouble,
        X01InMode.masterIn => hit.countsAsMaster,
      };

  bool _satisfiesOut(DartHit hit) => switch (outMode) {
        X01OutMode.straight => true,
        X01OutMode.doubleOut => hit.countsAsDouble,
        X01OutMode.masterOut => hit.countsAsMaster,
      };

  @override
  ApplyResult applyHit(Player player, DartHit hit) {
    if (currentTurnThrows.isEmpty) {
      _scoreAtTurnStart[player.id] = _remaining[player.id]!;
    }

    if (!(_opened[player.id] ?? true)) {
      if (!_satisfiesIn(hit)) {
        return const ApplyResult(pointsScored: 0);
      }
      _opened[player.id] = true;
    }

    final current = _remaining[player.id]!;
    final points = hit.points;
    final newScore = current - points;
    final outRequiresSpecialFinish = outMode != X01OutMode.straight;

    final isBust = newScore < 0 ||
        (newScore == 0 && !_satisfiesOut(hit)) ||
        (newScore == 1 && outRequiresSpecialFinish);

    if (isBust) {
      _remaining[player.id] = _scoreAtTurnStart[player.id]!;
      return ApplyResult(
        pointsScored: 0,
        bust: true,
        message: 'Bust! ${player.name} stays on ${_remaining[player.id]}.',
      );
    }

    _remaining[player.id] = newScore;

    if (newScore == 0) {
      return ApplyResult(
        pointsScored: points,
        endsGame: true,
        message: '${player.name} checks out!',
      );
    }
    return ApplyResult(pointsScored: points);
  }

  @override
  Object captureState() => {
        'remaining': Map<String, int>.from(_remaining),
        'opened': Map<String, bool>.from(_opened),
        'scoreAtTurnStart': Map<String, int>.from(_scoreAtTurnStart),
      };

  @override
  void restoreState(Object state) {
    final s = state as Map<String, Object>;
    _remaining
      ..clear()
      ..addAll(s['remaining'] as Map<String, int>);
    _opened
      ..clear()
      ..addAll(s['opened'] as Map<String, bool>);
    _scoreAtTurnStart
      ..clear()
      ..addAll(s['scoreAtTurnStart'] as Map<String, int>);
  }
}
