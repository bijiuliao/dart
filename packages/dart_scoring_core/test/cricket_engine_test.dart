import 'package:dart_scoring_core/dart_scoring_core.dart';
import 'package:test/test.dart';

const p1 = Player(id: 'p1', name: 'Alice');
const p2 = Player(id: 'p2', name: 'Bob');

void main() {
  group('CricketEngine standard scoring', () {
    test('triple closes a number in one dart', () {
      final engine = CricketEngine(players: const [p1, p2]);
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.triple, sector: 20));
      expect(engine.marksFor('p1', 20), 3);
      expect(engine.isClosed('p1', 20), isTrue);
    });

    test('overflow marks score points while an opponent is still open', () {
      final engine = CricketEngine(players: const [p1, p2]);
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.triple, sector: 20)); // closes 20, no overflow
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 19)); // p1 dart 2, unrelated
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 19)); // p1 dart 3, turn ends -> p2
      expect(engine.currentPlayer, p2);
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 1)); // irrelevant
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 1));
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 1)); // p2 turn ends -> p1

      // p1 hits 20 again: already closed by p1, p2 still open on 20 -> scores 20 points.
      final r = engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 20));
      expect(r.pointsScored, 20);
      expect(engine.pointsFor('p1'), 20);
    });

    test('marks are dead once every player has closed the number', () {
      final engine = CricketEngine(players: const [p1, p2]);
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.triple, sector: 20)); // p1 closes 20
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 1));
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 1)); // p1 turn ends
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.triple, sector: 20)); // p2 closes 20 too
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 1));
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 1)); // p2 turn ends -> p1

      final r = engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 20));
      expect(r.pointsScored, 0); // dead: nobody left to score off
      expect(engine.pointsFor('p1'), 0);
    });

    test('bullseye adds 2 marks, outer bull adds 1', () {
      final engine = CricketEngine(players: const [p1, p2]);
      engine.recordThrow(const DartHit.innerBull());
      expect(engine.marksFor('p1', 25), 2);
      engine.recordThrow(const DartHit.outerBull());
      expect(engine.marksFor('p1', 25), 3);
      expect(engine.isClosed('p1', 25), isTrue);
    });

    test('winner must have closed everything with the lead in points', () {
      final engine = CricketEngine(players: const [p1, p2]);
      const filler = DartHit.sectorHit(ring: DartRing.single, sector: 5); // not a Cricket target

      void closeTriple(int sector) =>
          engine.recordThrow(DartHit.sectorHit(ring: DartRing.triple, sector: sector));
      void p2Filler() {
        engine.recordThrow(filler);
        engine.recordThrow(filler);
        engine.recordThrow(filler);
      }

      closeTriple(20);
      closeTriple(19);
      closeTriple(18); // p1's turn ends -> p2
      p2Filler(); // -> p1

      closeTriple(17);
      closeTriple(16);
      closeTriple(15); // p1's turn ends -> p2
      p2Filler(); // -> p1

      expect(engine.hasClosedAll('p1'), isFalse); // bull still open
      engine.recordThrow(const DartHit.innerBull()); // 2 marks
      final finishing = engine.recordThrow(const DartHit.outerBull()); // 3rd mark -> closed

      expect(engine.hasClosedAll('p1'), isTrue);
      expect(engine.pointsFor('p1'), 0); // no overflow anywhere
      expect(engine.pointsFor('p2'), 0);
      expect(finishing.gameOver, isTrue); // 0 >= 0, p1 wins
      expect(engine.winner, p1);
    });
  });

  group('CricketEngine cut-throat scoring', () {
    test('overflow points penalize open opponents instead of the scorer', () {
      final engine = CricketEngine(
        players: const [p1, p2],
        scoringMode: CricketScoringMode.cutThroat,
      );
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.triple, sector: 20)); // p1 closes 20
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 1));
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 1)); // -> p2
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 1));
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 1));
      engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 1)); // -> p1

      final r = engine.recordThrow(const DartHit.sectorHit(ring: DartRing.single, sector: 20));
      expect(r.pointsScored, 0); // scorer gets nothing in cut-throat
      expect(engine.pointsFor('p1'), 0);
      expect(engine.pointsFor('p2'), 20); // opponent is penalized instead
    });
  });
}
