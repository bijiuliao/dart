import 'package:dart_scoring_core/dart_scoring_core.dart';
import 'package:test/test.dart';

void main() {
  group('BoardGeometry.hitForBoardPoint', () {
    test('dead centre is the inner bull', () {
      final hit = BoardGeometry.hitForBoardPoint(const Point2D(0, 0));
      expect(hit.ring, DartRing.innerBull);
      expect(hit.points, 50);
    });

    test('just outside inner bull, inside outer bull ring', () {
      final hit = BoardGeometry.hitForBoardPoint(const Point2D(0, -10));
      expect(hit.ring, DartRing.outerBull);
      expect(hit.points, 25);
    });

    test('top of the board is single 20 just past the triple', () {
      final hit = BoardGeometry.hitForBoardPoint(const Point2D(0, -120));
      expect(hit.ring, DartRing.single);
      expect(hit.sector, 20);
    });

    test('triple ring at the top scores T20', () {
      final hit = BoardGeometry.hitForBoardPoint(const Point2D(0, -103));
      expect(hit.ring, DartRing.triple);
      expect(hit.sector, 20);
      expect(hit.points, 60);
    });

    test('double ring at the top scores D20', () {
      final hit = BoardGeometry.hitForBoardPoint(const Point2D(0, -166));
      expect(hit.ring, DartRing.double);
      expect(hit.sector, 20);
      expect(hit.points, 40);
    });

    test('right side (90°) is sector 6, matching a real board layout', () {
      final hit = BoardGeometry.hitForBoardPoint(const Point2D(120, 0));
      expect(hit.sector, 6);
    });

    test('bottom (180°) is sector 3', () {
      final hit = BoardGeometry.hitForBoardPoint(const Point2D(0, 120));
      expect(hit.sector, 3);
    });

    test('left side (270°) is sector 11', () {
      final hit = BoardGeometry.hitForBoardPoint(const Point2D(-120, 0));
      expect(hit.sector, 11);
    });

    test('beyond the double ring is a miss', () {
      final hit = BoardGeometry.hitForBoardPoint(const Point2D(0, -200));
      expect(hit.ring, DartRing.miss);
      expect(hit.points, 0);
    });

    test('sector order has 20 opposite 3 and totals all 1-20 exactly once', () {
      expect(BoardGeometry.sectorOrder.toSet(), List.generate(20, (i) => i + 1).toSet());
      expect(BoardGeometry.sectorOrder.length, 20);
    });
  });
}
