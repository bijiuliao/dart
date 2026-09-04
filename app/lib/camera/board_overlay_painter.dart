import 'dart:math' as math;
import 'dart:ui';

import 'package:dart_scoring_core/dart_scoring_core.dart';
import 'package:flutter/material.dart';

/// Draws the 4 calibration crosshairs (and the quadrilateral connecting
/// them) as the player taps them on the calibration screen.
class CalibrationPointsPainter extends CustomPainter {
  final List<Offset> tappedPoints;

  CalibrationPointsPainter({required this.tappedPoints});

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = Colors.amber;
    final line = Paint()
      ..color = Colors.amber.withOpacity(0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final p in tappedPoints) {
      canvas.drawCircle(p, 6, dot);
      canvas.drawCircle(p, 14, line);
      canvas.drawLine(Offset(p.dx - 18, p.dy), Offset(p.dx + 18, p.dy), line);
      canvas.drawLine(Offset(p.dx, p.dy - 18), Offset(p.dx, p.dy + 18), line);
    }

    if (tappedPoints.length >= 2) {
      final path = Path()..moveTo(tappedPoints.first.dx, tappedPoints.first.dy);
      for (final p in tappedPoints.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      if (tappedPoints.length == 4) path.close();
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(covariant CalibrationPointsPainter oldDelegate) =>
      oldDelegate.tappedPoints != tappedPoints;
}

/// Once calibrated, projects the standard dartboard rings/sectors through
/// the homography and draws them over the live preview — lets the player
/// visually confirm the calibration lines up with the real board before
/// (and while) playing.
class BoardWireframePainter extends CustomPainter {
  final Homography calibration;
  final Color color;

  BoardWireframePainter({required this.calibration, this.color = Colors.cyanAccent});

  static const _radii = [
    BoardGeometry.innerBullRadius,
    BoardGeometry.outerBullRadius,
    BoardGeometry.tripleInnerRadius,
    BoardGeometry.tripleOuterRadius,
    BoardGeometry.doubleInnerRadius,
    BoardGeometry.doubleOuterRadius,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final r in _radii) {
      _drawProjectedCircle(canvas, r, paint);
    }

    // 20 sector-boundary spokes, from the outer bull edge to the double
    // ring's outer edge.
    for (var i = 0; i < 20; i++) {
      final angle = i * BoardGeometry.degreesPerSector -
          BoardGeometry.degreesPerSector / 2;
      final inner = _project(BoardGeometry.outerBullRadius, angle);
      final outer = _project(BoardGeometry.doubleOuterRadius, angle);
      canvas.drawLine(inner, outer, paint);
    }
  }

  Offset _project(double radiusMm, double angleDegrees) {
    final rad = angleDegrees * math.pi / 180.0;
    final boardPoint = Point2D(radiusMm * math.sin(rad), -radiusMm * math.cos(rad));
    final widgetPoint = calibration.apply(boardPoint);
    return Offset(widgetPoint.x, widgetPoint.y);
  }

  void _drawProjectedCircle(Canvas canvas, double radiusMm, Paint paint) {
    const steps = 72;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final angle = i * 360.0 / steps;
      final p = _project(radiusMm, angle);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BoardWireframePainter oldDelegate) =>
      oldDelegate.calibration != calibration || oldDelegate.color != color;
}

/// A single marker for the most recent dart (tapped or auto-detected),
/// colour-coded so a miscalibration or bad auto-detect is easy to spot at
/// a glance before it's confirmed.
class DartMarkerPainter extends CustomPainter {
  final Offset point;
  final DartHit hit;

  DartMarkerPainter({required this.point, required this.hit});

  Color get _color => switch (hit.ring) {
        DartRing.miss => Colors.grey,
        DartRing.innerBull => Colors.redAccent,
        DartRing.outerBull => Colors.green,
        DartRing.double => Colors.orangeAccent,
        DartRing.triple => Colors.purpleAccent,
        DartRing.single => Colors.lightBlueAccent,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = _color;
    final ring = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(point, 9, fill);
    canvas.drawCircle(point, 9, ring);
  }

  @override
  bool shouldRepaint(covariant DartMarkerPainter oldDelegate) =>
      oldDelegate.point != point || oldDelegate.hit != hit;
}
