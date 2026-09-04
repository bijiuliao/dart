import 'dart:ui';

/// Converts a point from the raw [CameraImage]'s pixel coordinates (as
/// produced by [DartLandingDetector]) into the coordinate space of the
/// on-screen preview widget the player calibrates and taps on.
///
/// This assumes the preview is displayed with **no crop**, e.g.:
///
/// ```dart
/// AspectRatio(
///   aspectRatio: controller.value.aspectRatio,
///   child: CameraPreview(controller),
/// )
/// ```
///
/// so the mapping is a uniform scale (plus, on most phones, a 90°
/// swap between the sensor's landscape buffer and a portrait preview).
/// Camera sensor/preview rotation handling is a known rough edge across
/// devices — this function is a reasonable default, not a guarantee. Use
/// the debug overlay dot on the calibration screen (shows exactly where
/// a raw detection maps to) to verify on your own device, and adjust
/// [assumeRotated] if it's mapping to the wrong axis.
Offset imagePointToWidgetPoint({
  required Offset imagePoint,
  required Size imageSize,
  required Size widgetSize,
  bool? assumeRotated,
}) {
  final bufferIsLandscape = imageSize.width >= imageSize.height;
  final widgetIsLandscape = widgetSize.width >= widgetSize.height;
  final rotated = assumeRotated ?? (bufferIsLandscape != widgetIsLandscape);

  final effectiveImageSize =
      rotated ? Size(imageSize.height, imageSize.width) : imageSize;
  final effectivePoint =
      rotated ? Offset(imagePoint.dy, imagePoint.dx) : imagePoint;

  final scaleX = widgetSize.width / effectiveImageSize.width;
  final scaleY = widgetSize.height / effectiveImageSize.height;
  return Offset(effectivePoint.dx * scaleX, effectivePoint.dy * scaleY);
}
