import 'package:dart_scoring_core/dart_scoring_core.dart';
import 'package:test/test.dart';

void main() {
  group('Homography', () {
    test('recovers an identity mapping', () {
      final pts = [
        const Point2D(0, 0),
        const Point2D(10, 0),
        const Point2D(10, 10),
        const Point2D(0, 10),
      ];
      final h = Homography.fromPointCorrespondences(src: pts, dst: pts);
      for (final p in pts) {
        final out = h.apply(p);
        expect(out.x, closeTo(p.x, 1e-6));
        expect(out.y, closeTo(p.y, 1e-6));
      }
    });

    test('recovers a pure scale + translate mapping', () {
      final src = [
        const Point2D(0, 0),
        const Point2D(1, 0),
        const Point2D(1, 1),
        const Point2D(0, 1),
      ];
      // scale by 100, translate by (50, 20) -- like board mm -> a screen
      final dst = src.map((p) => Point2D(p.x * 100 + 50, p.y * 100 + 20)).toList();
      final h = Homography.fromPointCorrespondences(src: src, dst: dst);

      final probe = const Point2D(0.5, 0.5);
      final out = h.apply(probe);
      expect(out.x, closeTo(100, 1e-6));
      expect(out.y, closeTo(70, 1e-6));
    });

    test('forward then backward round-trips for a perspective (skewed) mapping', () {
      // A square mapped to a non-trivial quadrilateral, simulating a
      // camera looking at the board from an angle.
      final src = [
        const Point2D(-170, -170),
        const Point2D(170, -170),
        const Point2D(170, 170),
        const Point2D(-170, 170),
      ];
      final dst = [
        const Point2D(120, 80),
        const Point2D(520, 60),
        const Point2D(560, 460),
        const Point2D(90, 430),
      ];
      final h = Homography.fromPointCorrespondences(src: src, dst: dst);

      // The 4 calibration points should map (near) exactly.
      for (var i = 0; i < src.length; i++) {
        final out = h.apply(src[i]);
        expect(out.x, closeTo(dst[i].x, 1e-3));
        expect(out.y, closeTo(dst[i].y, 1e-3));
      }

      // And an interior point should round-trip through inverse+forward.
      const interior = Point2D(30, -15);
      final imagePoint = h.apply(interior);
      final back = h.applyInverse(imagePoint);
      expect(back.x, closeTo(interior.x, 1e-3));
      expect(back.y, closeTo(interior.y, 1e-3));
    });

    test('least-squares fit with more than 4 points stays close', () {
      final src = <Point2D>[];
      final dst = <Point2D>[];
      for (final p in [
        const Point2D(0, 0),
        const Point2D(10, 0),
        const Point2D(10, 10),
        const Point2D(0, 10),
        const Point2D(5, 5),
        const Point2D(2, 8),
      ]) {
        src.add(p);
        // small deterministic jitter so it isn't a perfect fit
        final jitterX = (p.x % 3 == 0) ? 0.05 : -0.05;
        dst.add(Point2D(p.x * 10 + 100 + jitterX, p.y * 10 + 50));
      }
      final h = Homography.fromPointCorrespondences(src: src, dst: dst);
      final out = h.apply(const Point2D(5, 5));
      expect(out.x, closeTo(150, 1));
      expect(out.y, closeTo(100, 1));
    });

    test('throws with fewer than 4 correspondences', () {
      expect(
        () => Homography.fromPointCorrespondences(
          src: const [Point2D(0, 0), Point2D(1, 0), Point2D(1, 1)],
          dst: const [Point2D(0, 0), Point2D(1, 0), Point2D(1, 1)],
        ),
        throwsArgumentError,
      );
    });
  });
}
