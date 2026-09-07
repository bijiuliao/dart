import 'dart:ui';

import 'package:camera/camera.dart';

/// A dart landing found by [DartLandingDetector], in the raw camera
/// image's own pixel coordinates (i.e. `CameraImage.width/height`, which
/// on most devices is the sensor's landscape buffer size, *not* the
/// on-screen preview widget's size — see `frame_geometry.dart` for
/// converting this into preview-widget coordinates before scoring).
class DetectedLanding {
  final Offset imagePoint;
  final Size imageSize;
  const DetectedLanding(this.imagePoint, this.imageSize);
}

/// A snapshot of the detector's internal state after the most recently
/// processed frame. Exposed purely for diagnostics — e.g. a debug
/// overlay on the scoring screen — so it's possible to tell *why*
/// auto-detect isn't firing: is the picture too jittery to ever read as
/// "still" (handheld shake, autofocus hunting, flickering light), or has
/// no motion been seen at all (dart flight not entering frame)?
class DartLandingDebugState {
  /// Changed blocks between this frame and the previous one.
  final int changedVsLastFrame;

  /// Whether a big-enough motion event has been seen since the last
  /// confirmed/reset baseline (the detector is now watching for it to
  /// settle).
  final bool motionSeen;

  /// Consecutive "quiet" frames seen so far towards [stillFramesRequired].
  final int stillCount;
  final int stillFramesRequired;

  const DartLandingDebugState({
    required this.changedVsLastFrame,
    required this.motionSeen,
    required this.stillCount,
    required this.stillFramesRequired,
  });

  @override
  String toString() => motionSeen
      ? '動態 $changedVsLastFrame・穩定 $stillCount/$stillFramesRequired'
      : '動態 $changedVsLastFrame・等待偵測到大動作';
}

/// Best-effort, frame-difference based detector that watches the camera
/// image stream for "something new and small appeared, then stopped
/// moving" — i.e. a dart sticking in the board — and reports where.
///
/// This is deliberately simple (no external CV/ML dependency) so it runs
/// on-device in real time, but it is a heuristic: lighting changes,
/// camera shake, or a hand lingering near the board can all confuse it.
/// It is meant to drive the app's optional "auto-detect" mode, always
/// alongside a manual correction/entry path — see [GameController] and
/// the scoring screen's tap-to-score fallback.
///
/// Tuning knobs (constructor parameters) trade sensitivity for false
/// positives; defaults are a reasonable starting point for a phone
/// mounted a stable ~1-1.5m from the board with steady lighting. A
/// handheld phone's own micro-shake is often enough to keep
/// [changedVsLastFrame] above the "quiet" threshold forever, so a dart
/// landing never gets to be confirmed — see [debugState].
class DartLandingDetector {
  final int gridCols;
  final int gridRows;

  /// Per-block average-luminance change (0-255 scale) considered
  /// "different".
  final double motionThreshold;

  /// How many consecutive still frames are required after motion before
  /// a landing is confirmed (filters out darts still wobbling).
  final int stillFramesRequired;

  /// A candidate must involve at least this many changed blocks...
  final int minChangedBlocksForDart;

  /// ...and no more than this many (a bigger blob is assumed to be an arm
  /// or body in frame, e.g. someone walking up to pull darts, not a dart
  /// landing).
  final int maxChangedBlocksForDart;

  DartLandingDetector({
    this.gridCols = 40,
    this.gridRows = 30,
    this.motionThreshold = 18,
    this.stillFramesRequired = 4,
    this.minChangedBlocksForDart = 1,
    this.maxChangedBlocksForDart = 40,
  });

  List<double>? _baseline;
  List<double>? _lastFrame;
  int _stillCount = 0;
  bool _motionSeen = false;
  DartLandingDebugState? _debugState;

  /// State after the most recently processed frame — read this from the
  /// UI (after each [processFrame] call) to show a live diagnostic.
  DartLandingDebugState? get debugState => _debugState;

  /// Feed one camera frame in. Returns a [DetectedLanding] the moment a
  /// new, localized, now-still change is found, otherwise null. Always
  /// updates [debugState], regardless of the outcome.
  DetectedLanding? processFrame(CameraImage image) {
    final blocks = _computeBlockLuminance(image);

    if (_baseline == null) {
      _baseline = blocks;
      _lastFrame = blocks;
      _updateDebug(0);
      return null;
    }

    final changedNow =
        _countChanged(blocks, _lastFrame!, threshold: motionThreshold);
    _lastFrame = blocks;

    if (changedNow > maxChangedBlocksForDart) {
      // Big motion in frame (an arm reaching in, a body walking past):
      // wait for it to settle before looking for a new dart.
      _motionSeen = true;
      _stillCount = 0;
      _updateDebug(changedNow);
      return null;
    }

    if (changedNow > minChangedBlocksForDart) {
      // Still settling.
      _stillCount = 0;
      _updateDebug(changedNow);
      return null;
    }

    _stillCount++;
    _updateDebug(changedNow);
    if (!_motionSeen || _stillCount < stillFramesRequired) return null;

    // Motion happened and the scene has now settled: whatever differs
    // from the pre-motion baseline is presumably the new dart.
    final changedBlocks = <int>[];
    for (var i = 0; i < blocks.length; i++) {
      if ((blocks[i] - _baseline![i]).abs() > motionThreshold) {
        changedBlocks.add(i);
      }
    }

    _motionSeen = false;
    _stillCount = 0;
    _baseline = blocks; // adopt the settled frame so we don't re-trigger.
    _updateDebug(changedNow);

    if (changedBlocks.length < minChangedBlocksForDart ||
        changedBlocks.length > maxChangedBlocksForDart) {
      return null;
    }

    final blockW = image.width / gridCols;
    final blockH = image.height / gridRows;
    var sumX = 0.0, sumY = 0.0;
    for (final idx in changedBlocks) {
      final col = idx % gridCols;
      final row = idx ~/ gridCols;
      sumX += (col + 0.5) * blockW;
      sumY += (row + 0.5) * blockH;
    }
    final centroid = Offset(
      sumX / changedBlocks.length,
      sumY / changedBlocks.length,
    );
    return DetectedLanding(
      centroid,
      Size(image.width.toDouble(), image.height.toDouble()),
    );
  }

  void _updateDebug(int changedNow) {
    _debugState = DartLandingDebugState(
      changedVsLastFrame: changedNow,
      motionSeen: _motionSeen,
      stillCount: _stillCount,
      stillFramesRequired: stillFramesRequired,
    );
  }

  /// Forces the next stable frame to be treated as a fresh baseline —
  /// call this right after a dart is pulled from the board (or the
  /// player confirms/discards a detection) so the next real change is
  /// measured from a clean slate.
  void reset() {
    _baseline = null;
    _lastFrame = null;
    _stillCount = 0;
    _motionSeen = false;
    _debugState = null;
  }

  int _countChanged(List<double> a, List<double> b, {required double threshold}) {
    var count = 0;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > threshold) count++;
    }
    return count;
  }

  /// Downsamples the frame to a `gridCols x gridRows` grid of average
  /// luminance, sampling every few pixels for speed. Handles both the
  /// single-plane BGRA8888 format (iOS) and YUV420 (Android), where the
  /// first plane is already the luma (Y) channel.
  List<double> _computeBlockLuminance(CameraImage image) {
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final stride = plane.bytesPerRow;
    final width = image.width;
    final height = image.height;
    final bytesPerPixel =
        image.format.group == ImageFormatGroup.bgra8888 ? 4 : 1;

    final blockW = (width / gridCols).ceil().clamp(1, width);
    final blockH = (height / gridRows).ceil().clamp(1, height);
    final sums = List<double>.filled(gridCols * gridRows, 0);
    final counts = List<int>.filled(gridCols * gridRows, 0);

    const step = 4; // sample every 4th pixel in each direction
    for (var y = 0; y < height; y += step) {
      final blockRow = (y ~/ blockH).clamp(0, gridRows - 1);
      final rowOffset = y * stride;
      for (var x = 0; x < width; x += step) {
        final blockCol = (x ~/ blockW).clamp(0, gridCols - 1);
        final pixelOffset = rowOffset + x * bytesPerPixel;
        if (pixelOffset < 0 || pixelOffset >= bytes.length) continue;

        double luma;
        if (bytesPerPixel == 4) {
          final b = bytes[pixelOffset];
          final g = bytes[pixelOffset + 1];
          final r = bytes[pixelOffset + 2];
          luma = 0.114 * b + 0.587 * g + 0.299 * r;
        } else {
          luma = bytes[pixelOffset].toDouble();
        }

        final idx = blockRow * gridCols + blockCol;
        sums[idx] += luma;
        counts[idx]++;
      }
    }

    return [
      for (var i = 0; i < sums.length; i++)
        counts[i] == 0 ? 0.0 : sums[i] / counts[i],
    ];
  }
}
