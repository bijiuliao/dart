import '../../board/dart_hit.dart';
import '../game_engine.dart';
import '../player.dart';

/// "占地盤" (territory) games: standard Cricket, Cut-throat Cricket, or a
/// no-scoring "first to close everything" variant.
enum CricketScoringMode { standard, cutThroat, noScore }

/// Cricket. Targets are 20, 19, 18, 17, 16, 15 and Bull (25). A
/// single/double/triple hit adds 1/2/3 marks to that target; 3 marks
/// "closes" it for that player. By convention here, hitting the outer
/// bull adds 1 mark and the inner bull (bullseye) adds 2 marks, since the
/// bullseye is worth 50 = "double 25". Once a player has closed a
/// number, further marks on it are dead if every other player has also
/// closed it; otherwise each extra mark scores points equal to the
/// target's value (25 for bull):
///  - [CricketScoringMode.standard]: points are added to the scoring
///    player's own total.
///  - [CricketScoringMode.cutThroat]: points are instead added to every
///    opponent who still has that number open (you're saddling them with
///    points, not helping yourself) — the winner is whoever closes every
///    number with the *lowest* total.
///  - [CricketScoringMode.noScore]: no points are tracked at all; first
///    to close every number wins outright.
/// A player wins by closing all 7 targets while their point total is
/// at least as good as every other player's (>= for standard, <= for
/// cut-throat) — closing everything with a worse total just means the
/// game continues.
class CricketEngine extends BaseGameEngine {
  static const List<int> numbers = [20, 19, 18, 17, 16, 15];
  static const int bullValue = 25;
  static const List<int> allTargets = [20, 19, 18, 17, 16, 15, bullValue];

  final CricketScoringMode scoringMode;

  final Map<String, Map<int, int>> _marks = {};
  final Map<String, int> _points = {};

  CricketEngine({
    required List<Player> players,
    this.scoringMode = CricketScoringMode.standard,
  }) : super(players) {
    for (final p in players) {
      _marks[p.id] = {for (final n in allTargets) n: 0};
      _points[p.id] = 0;
    }
  }

  int marksFor(String playerId, int target) => _marks[playerId]?[target] ?? 0;
  int pointsFor(String playerId) => _points[playerId] ?? 0;
  bool isClosed(String playerId, int target) => marksFor(playerId, target) >= 3;
  bool hasClosedAll(String playerId) =>
      allTargets.every((t) => isClosed(playerId, t));

  int? _targetForHit(DartHit hit) {
    if (hit.ring == DartRing.innerBull || hit.ring == DartRing.outerBull) {
      return bullValue;
    }
    if (hit.sector != null && numbers.contains(hit.sector)) return hit.sector;
    return null; // Not a Cricket number: no effect, but still a used dart.
  }

  int _marksForHit(DartHit hit) {
    if (hit.ring == DartRing.innerBull) return 2;
    if (hit.ring == DartRing.outerBull) return 1;
    return hit.multiplier; // single/double/triple -> 1/2/3
  }

  @override
  ApplyResult applyHit(Player player, DartHit hit) {
    final target = _targetForHit(hit);
    if (target == null) {
      return const ApplyResult(pointsScored: 0);
    }

    final marksMap = _marks[player.id]!;
    final currentMarks = marksMap[target]!;
    final marksToAdd = _marksForHit(hit);
    final room = 3 - currentMarks;
    final applied = marksToAdd < room ? marksToAdd : room;
    final overflow = marksToAdd - applied;
    marksMap[target] = currentMarks + applied;

    var pointsScoredThisThrow = 0;
    if (overflow > 0 && scoringMode != CricketScoringMode.noScore) {
      final openOpponents = players
          .where((p) => p.id != player.id && _marks[p.id]![target]! < 3)
          .toList();
      if (openOpponents.isNotEmpty) {
        final gained = target * overflow;
        if (scoringMode == CricketScoringMode.standard) {
          _points[player.id] = _points[player.id]! + gained;
          pointsScoredThisThrow = gained;
        } else {
          // Cut-throat: the scoring player gives points to whoever is
          // still open on this number, rather than keeping them.
          for (final opp in openOpponents) {
            _points[opp.id] = _points[opp.id]! + gained;
          }
        }
      }
    }

    var endsGame = false;
    if (hasClosedAll(player.id)) {
      switch (scoringMode) {
        case CricketScoringMode.noScore:
          endsGame = true;
        case CricketScoringMode.standard:
          endsGame = players.every(
              (p) => p.id == player.id || _points[player.id]! >= _points[p.id]!);
        case CricketScoringMode.cutThroat:
          endsGame = players.every(
              (p) => p.id == player.id || _points[player.id]! <= _points[p.id]!);
      }
    }

    return ApplyResult(
      pointsScored: pointsScoredThisThrow,
      endsGame: endsGame,
    );
  }

  @override
  Object captureState() => {
        'marks': {
          for (final e in _marks.entries) e.key: Map<int, int>.from(e.value),
        },
        'points': Map<String, int>.from(_points),
      };

  @override
  void restoreState(Object state) {
    final s = state as Map<String, Object>;
    final marks = s['marks'] as Map<String, Map<int, int>>;
    _marks
      ..clear()
      ..addAll({for (final e in marks.entries) e.key: Map<int, int>.from(e.value)});
    _points
      ..clear()
      ..addAll(s['points'] as Map<String, int>);
  }
}
