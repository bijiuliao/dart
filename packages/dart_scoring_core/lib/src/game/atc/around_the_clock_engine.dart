import '../../board/dart_hit.dart';
import '../game_engine.dart';
import '../player.dart';

/// Around the Clock: each player works through 1, 2, 3, ... 20, then Bull
/// in order, advancing to the next number only by hitting their current
/// target. First to reach the end wins. Set [requireDouble] for the
/// harder "doubles" variant, where the target number must be hit as a
/// double (any bull ring still counts as "Bull" for the final step).
class AroundTheClockEngine extends BaseGameEngine {
  static const List<int> sequence = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    25, // Bull, final target
  ];

  final bool requireDouble;
  final Map<String, int> _targetIndex = {};

  AroundTheClockEngine({
    required List<Player> players,
    this.requireDouble = false,
  }) : super(players) {
    for (final p in players) {
      _targetIndex[p.id] = 0;
    }
  }

  /// The number (1-20, or 25 for Bull) this player needs to hit next.
  int currentTargetFor(String playerId) => sequence[_targetIndex[playerId]!];

  /// How many of the 21 targets this player has completed (0-21).
  int progressFor(String playerId) => _targetIndex[playerId]!;

  @override
  ApplyResult applyHit(Player player, DartHit hit) {
    final idx = _targetIndex[player.id]!;
    final target = sequence[idx];

    final bool hitTarget;
    if (target == 25) {
      hitTarget = hit.ring == DartRing.innerBull || hit.ring == DartRing.outerBull;
    } else {
      hitTarget = hit.sector == target && (!requireDouble || hit.ring == DartRing.double);
    }

    if (!hitTarget) return const ApplyResult(pointsScored: 0);

    final newIdx = idx + 1;
    _targetIndex[player.id] = newIdx;

    if (newIdx >= sequence.length) {
      return ApplyResult(
        pointsScored: hit.points,
        endsGame: true,
        message: '${player.name} finished Around the Clock!',
      );
    }
    return ApplyResult(pointsScored: hit.points);
  }

  @override
  Object captureState() => Map<String, int>.from(_targetIndex);

  @override
  void restoreState(Object state) {
    _targetIndex
      ..clear()
      ..addAll(state as Map<String, int>);
  }
}
