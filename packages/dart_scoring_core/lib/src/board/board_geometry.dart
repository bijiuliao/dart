import 'dart:math' as math;

import '../geometry/point2d.dart';
import 'dart_hit.dart';

/// Standard steel-tip dartboard dimensions, in millimetres from the board
/// centre (per WDF/PDC regulation boards). Used to turn a board-plane
/// point (see [Homography]) into a [DartHit].
class BoardGeometry {
  const BoardGeometry._();

  static const double innerBullRadius = 6.35;
  static const double outerBullRadius = 15.9;
  static const double tripleInnerRadius = 99.0;
  static const double tripleOuterRadius = 107.0;
  static const double doubleInnerRadius = 162.0;
  static const double doubleOuterRadius = 170.0;

  /// Radius of the whole scoring area (== outer edge of the double ring).
  /// Anything beyond this is a miss.
  static const double boardRadius = doubleOuterRadius;

  /// The 20 sector values in clockwise order starting from the sector
  /// centred at the top of the board (12 o'clock / 0°).
  static const List<int> sectorOrder = [
    20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5,
  ];

  static const double degreesPerSector = 360.0 / 20.0; // 18°

  /// Board-plane coordinates (mm, centred on the bullseye) of the outer
  /// edge of the double ring at the four cardinal directions used for
  /// camera calibration: top (centre of "20"), right (centre of "6"),
  /// bottom (centre of "3") and left (centre of "11"). Angles are
  /// clockwise from north, matching [angleForBoardPoint].
  static Point2D calibrationPoint(double angleDegrees) {
    final rad = angleDegrees * math.pi / 180.0;
    // x = r*sin(theta), y = -r*cos(theta): theta=0 -> (0,-r) i.e. "up".
    return Point2D(
      doubleOuterRadius * math.sin(rad),
      -doubleOuterRadius * math.cos(rad),
    );
  }

  static final List<Point2D> defaultCalibrationPoints = [
    calibrationPoint(0), // top edge, over the "20"
    calibrationPoint(90), // right edge, over the "6"
    calibrationPoint(180), // bottom edge, over the "3"
    calibrationPoint(270), // left edge, over the "11"
  ];

  /// Angle, in degrees clockwise from north (top of the board / centre of
  /// the "20" sector), of a board-plane point.
  static double angleForBoardPoint(Point2D p) {
    final deg = math.atan2(p.x, -p.y) * 180.0 / math.pi;
    return (deg + 360.0) % 360.0;
  }

  static double radiusForBoardPoint(Point2D p) =>
      math.sqrt(p.x * p.x + p.y * p.y);

  /// The sector value (1-20) whose wedge a given angle falls in.
  static int sectorForAngle(double angleDegrees) {
    final normalized = (angleDegrees + degreesPerSector / 2) % 360.0;
    final index = (normalized / degreesPerSector).floor() % sectorOrder.length;
    return sectorOrder[index];
  }

  /// Scores a point already expressed in board-plane millimetres (i.e.
  /// after applying the calibrated inverse homography to an image pixel).
  static DartHit hitForBoardPoint(Point2D p) {
    final r = radiusForBoardPoint(p);

    if (r <= innerBullRadius) return const DartHit.innerBull();
    if (r <= outerBullRadius) return const DartHit.outerBull();
    if (r > doubleOuterRadius) return const DartHit.miss();

    final sector = sectorForAngle(angleForBoardPoint(p));
    if (r <= tripleInnerRadius) {
      return DartHit(ring: DartRing.single, sector: sector);
    }
    if (r <= tripleOuterRadius) {
      return DartHit(ring: DartRing.triple, sector: sector);
    }
    if (r <= doubleInnerRadius) {
      return DartHit(ring: DartRing.single, sector: sector);
    }
    return DartHit(ring: DartRing.double, sector: sector);
  }
}
