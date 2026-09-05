import 'dart:math' as math;

import 'package:dart_scoring_core/dart_scoring_core.dart';
import 'package:flutter/material.dart';

/// A drawn, tappable dartboard. Always available as the reliable manual
/// scoring path (and for correcting an auto-detected/camera-tapped dart):
/// tap where the dart landed and it resolves straight to a [DartHit]
/// through the exact same [BoardGeometry] math the camera path uses.
class DartboardTapWidget extends StatelessWidget {
  final ValueChanged<DartHit> onHit;

  const DartboardTapWidget({super.key, required this.onHit});

  static const _darkSingle = Colors.black;
  static const _lightSingle = Color(0xFFE9DFC6);
  static const _red = Color(0xFFC8202E);
  static const _green = Color(0xFF0B7A3B);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: GestureDetector(
              key: const ValueKey('dartboardTapTarget'),
              onTapDown: (details) => _handleTap(details.localPosition, side),
              child: CustomPaint(
                painter: _DartboardPainter(),
                size: Size(side, side),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset local, double side) {
    final center = Offset(side / 2, side / 2);
    final scale = (side / 2) / BoardGeometry.doubleOuterRadius;
    final dx = (local.dx - center.dx) / scale;
    final dy = (local.dy - center.dy) / scale;
    onHit(BoardGeometry.hitForBoardPoint(Point2D(dx, dy)));
  }
}

class _DartboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = (size.width / 2) / BoardGeometry.doubleOuterRadius;

    final backdrop = Paint()..color = Colors.black;
    canvas.drawCircle(center, size.width / 2, backdrop);

    for (var i = 0; i < 20; i++) {
      final sectorValue = BoardGeometry.sectorOrder[i];
      final isEven = i.isEven;
      final singleColor =
          isEven ? DartboardTapWidget._darkSingle : DartboardTapWidget._lightSingle;
      final bandColor = isEven ? DartboardTapWidget._red : DartboardTapWidget._green;
      final start = i * BoardGeometry.degreesPerSector - BoardGeometry.degreesPerSector / 2;
      final end = start + BoardGeometry.degreesPerSector;

      _fillAnnulus(canvas, center, scale, start, end,
          BoardGeometry.outerBullRadius, BoardGeometry.tripleInnerRadius, singleColor);
      _fillAnnulus(canvas, center, scale, start, end,
          BoardGeometry.tripleInnerRadius, BoardGeometry.tripleOuterRadius, bandColor);
      _fillAnnulus(canvas, center, scale, start, end,
          BoardGeometry.tripleOuterRadius, BoardGeometry.doubleInnerRadius, singleColor);
      _fillAnnulus(canvas, center, scale, start, end,
          BoardGeometry.doubleInnerRadius, BoardGeometry.doubleOuterRadius, bandColor);

      _drawLabel(canvas, center, scale, sectorValue, i * BoardGeometry.degreesPerSector);
    }

    canvas.drawCircle(center, BoardGeometry.outerBullRadius * scale, Paint()..color = DartboardTapWidget._green);
    canvas.drawCircle(center, BoardGeometry.innerBullRadius * scale, Paint()..color = DartboardTapWidget._red);

    final wireColor = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, BoardGeometry.doubleOuterRadius * scale, wireColor);
  }

  Offset _polar(Offset center, double scale, double radiusMm, double angleDeg) {
    final rad = angleDeg * math.pi / 180.0;
    return center + Offset(radiusMm * scale * math.sin(rad), -radiusMm * scale * math.cos(rad));
  }

  void _fillAnnulus(
    Canvas canvas,
    Offset center,
    double scale,
    double startDeg,
    double endDeg,
    double innerMm,
    double outerMm,
    Color color,
  ) {
    const steps = 6;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final t = startDeg + (endDeg - startDeg) * i / steps;
      final p = _polar(center, scale, outerMm, t);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    for (var i = steps; i >= 0; i--) {
      final t = startDeg + (endDeg - startDeg) * i / steps;
      final p = _polar(center, scale, innerMm, t);
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawLabel(Canvas canvas, Offset center, double scale, int value, double angleDeg) {
    final p = _polar(center, scale, BoardGeometry.doubleOuterRadius + 12, angleDeg);
    final painter = TextPainter(
      text: TextSpan(
        text: '$value',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, p - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DartboardPainter oldDelegate) => false;
}
