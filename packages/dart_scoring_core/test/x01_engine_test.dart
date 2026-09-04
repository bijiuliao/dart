import 'package:dart_scoring_core/dart_scoring_core.dart';
import 'package:test/test.dart';

const p1 = Player(id: 'p1', name: 'Alice');
const p2 = Player(id: 'p2', name: 'Bob');

void main() {
  group('X01Engine straight-out', () {
    test('scores three darts and keeps the same player until 3 darts', () {
      final engine = X01Engine(
        players: const [p1, p2],
        startingScore: 501,
        outMode: X01OutMode.straight,
      );
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.triple, sector: 20)); // 60
      expect(engine.currentPlayer, p1);
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.triple, sector: 20)); // 60
      expect(engine.currentPlayer, p1);
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.triple, sector: 20)); // 60
      expect(engine.remainingScore('p1'), 501 - 180);
      expect(engine.currentPlayer, p2); // auto-advanced after 3 darts
    });

    test('any finish is valid in straight-out mode', () {
      final engine = X01Engine(
        players: const [p1],
        startingScore: 40,
        outMode: X01OutMode.straight,
      );
      final outcome = engine.recordThrow(
        const DartHit.sectorHit(ring: DartRing.single, sector: 20), // 20
      );
      expect(outcome.gameOver, isFalse);
      final finish = engine.recordThrow(
        const DartHit.sectorHit(ring: DartRing.single, sector: 20), // 20 -> 0
      );
      expect(finish.gameOver, isTrue);
      expect(engine.winner, p1);
    });
  });

  group('X01Engine double-out (standard 501)', () {
    test('busts on overshoot and reverts to the score at turn start', () {
      // Get p1 down to a low score first.
      X01Engine solo = X01Engine(players: const [p1], startingScore: 41);
      final r1 = solo.recordThrow(
        const DartHit.sectorHit(ring: DartRing.triple, sector: 20), // 60 > 41
      );
      expect(r1.bust, isTrue);
      expect(solo.remainingScore('p1'), 41); // reverted
      expect(r1.turnEnded, isTrue); // bust ends the turn immediately
    });

    test('busts when reaching exactly 1 (impossible to finish on a double)', () {
      final solo = X01Engine(players: const [p1], startingScore: 21);
      final r = solo.recordThrow(
        const DartHit.sectorHit(ring: DartRing.single, sector: 20), // 21 -> 1
      );
      expect(r.bust, isTrue);
      expect(solo.remainingScore('p1'), 21);
    });

    test('busts when reaching exactly 0 without a double', () {
      final solo = X01Engine(players: const [p1], startingScore: 20);
      final r = solo.recordThrow(
        const DartHit.sectorHit(ring: DartRing.single, sector: 20), // 20 -> 0 single
      );
      expect(r.bust, isTrue);
    });

    test('checks out on a valid double', () {
      final solo = X01Engine(players: const [p1], startingScore: 40);
      final r = solo.recordThrow(
        const DartHit.sectorHit(ring: DartRing.double, sector: 20), // D20 -> 0
      );
      expect(r.bust, isFalse);
      expect(r.gameOver, isTrue);
      expect(solo.winner, p1);
    });

    test('bullseye counts as a double for checkout', () {
      final solo = X01Engine(players: const [p1], startingScore: 50);
      final r = solo.recordThrow(const DartHit.innerBull());
      expect(r.gameOver, isTrue);
    });
  });

  group('X01Engine undo', () {
    test('undo restores score and whose turn it is', () {
      final engine = X01Engine(players: const [p1, p2], startingScore: 501);
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 20));
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 20));
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 20)); // turn ends, -> p2
      expect(engine.currentPlayer, p2);

      final ok = engine.undoLastThrow();
      expect(ok, isTrue);
      expect(engine.currentPlayer, p1); // back to p1's turn
      expect(engine.remainingScore('p1'), 501 - 40); // only 2 darts counted now
      expect(engine.currentTurnThrows.length, 2);
    });
  });
}
