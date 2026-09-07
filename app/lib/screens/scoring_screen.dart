import 'package:camera/camera.dart';
import 'package:dart_scoring_core/dart_scoring_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../camera/board_overlay_painter.dart';
import '../camera/dart_landing_detector.dart';
import '../camera/frame_geometry.dart';
import '../state/game_controller.dart';
import '../widgets/atc_scoreboard.dart';
import '../widgets/cricket_scoreboard.dart';
import '../widgets/dartboard_tap_widget.dart';
import '../widgets/throw_history_list.dart';
import '../widgets/x01_scoreboard.dart';
import 'calibration_screen.dart';
import 'home_screen.dart';

/// The main gameplay screen: live (calibrated) camera preview with
/// tap-to-score and optional auto-detect, or a plain manual dartboard if
/// the player skipped calibration — either way it drives the same
/// [GameController]/[GameEngine], so switching between them mid-game is
/// safe.
class ScoringScreen extends StatefulWidget {
  const ScoringScreen({super.key});

  @override
  State<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends State<ScoringScreen> {
  final _previewKey = GlobalKey();
  final _detector = DartLandingDetector();

  CameraController? _cameraController;
  String? _cameraError;
  bool _streaming = false;

  Offset? _lastMarkerPoint;
  DartHit? _lastHit;

  /// Live diagnostic for auto-detect mode — see [DartLandingDebugState].
  /// A [ValueNotifier] so it can update on every camera frame without
  /// rebuilding the whole screen.
  final ValueNotifier<DartLandingDebugState?> _debugState = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    if (context.read<GameController>().isCalibrated) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = '找不到可用的相機');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final cam = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await cam.initialize();
      if (!mounted) return;
      setState(() => _cameraController = cam);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cameraError = '無法開啟相機：$e');
    }
  }

  void _syncImageStream(bool autoDetectEnabled) {
    final cam = _cameraController;
    if (cam == null || !cam.value.isInitialized) return;
    if (autoDetectEnabled && !_streaming) {
      _streaming = true;
      _detector.reset();
      cam.startImageStream(_onCameraImage);
    } else if (!autoDetectEnabled && _streaming) {
      _streaming = false;
      cam.stopImageStream();
    }
  }

  void _onCameraImage(CameraImage image) {
    final landing = _detector.processFrame(image);
    _debugState.value = _detector.debugState;
    if (landing == null) return;

    final renderBox = _previewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final widgetPoint = imagePointToWidgetPoint(
      imagePoint: landing.imagePoint,
      imageSize: landing.imageSize,
      widgetSize: renderBox.size,
    );
    _scoreAt(widgetPoint, autoDetected: true);
  }

  void _scoreAt(Offset widgetPoint, {required bool autoDetected}) {
    final controller = context.read<GameController>();
    final calibration = controller.calibration;
    if (calibration == null) return;

    final boardPoint = calibration.applyInverse(Point2D(widgetPoint.dx, widgetPoint.dy));
    final hit = BoardGeometry.hitForBoardPoint(boardPoint);
    if (!mounted) return;
    setState(() {
      _lastMarkerPoint = widgetPoint;
      _lastHit = hit;
    });
    controller.recordHit(hit, autoDetected: autoDetected);
    _detector.reset();
  }

  void _handleManualHit(DartHit hit) {
    context.read<GameController>().recordHit(hit, autoDetected: false);
  }

  Future<void> _openCalibration() async {
    if (_streaming) {
      _streaming = false;
      await _cameraController?.stopImageStream();
    }
    await _cameraController?.dispose();
    _cameraController = null;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CalibrationScreen()),
    );
    if (!mounted) return;
    if (context.read<GameController>().isCalibrated) {
      _initCamera();
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (_streaming) {
      _cameraController?.stopImageStream();
    }
    _cameraController?.dispose();
    _debugState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final engine = controller.engine;

    if (engine == null) {
      // Defensive: shouldn't normally happen (this screen is only pushed
      // once a game has been started), but avoid a crash if it does.
      return const HomeScreen();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncImageStream(controller.autoDetectEnabled);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(engine.currentPlayer.name),
        actions: [
          IconButton(
            tooltip: '校準相機',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _openCalibration,
          ),
          IconButton(
            tooltip: '結束遊戲',
            icon: const Icon(Icons.close),
            onPressed: () => _confirmEndGame(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBoardArea(controller)),
            _buildControls(context, controller, engine),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardArea(GameController controller) {
    if (!controller.isCalibrated) {
      return DartboardTapWidget(onHit: _handleManualHit);
    }
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_cameraError!, textAlign: TextAlign.center),
        ),
      );
    }
    final cam = _cameraController;
    if (cam == null || !cam.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: AspectRatio(
        aspectRatio: cam.value.aspectRatio,
        child: GestureDetector(
          onTapDown: (d) => _scoreAt(d.localPosition, autoDetected: false),
          child: Stack(
            key: _previewKey,
            fit: StackFit.expand,
            children: [
              CameraPreview(cam),
              CustomPaint(painter: BoardWireframePainter(calibration: controller.calibration!)),
              if (_lastMarkerPoint != null && _lastHit != null)
                CustomPaint(painter: DartMarkerPainter(point: _lastMarkerPoint!, hit: _lastHit!)),
              if (controller.autoDetectEnabled)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: _AutoDetectDebugBanner(debugState: _debugState),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, GameController controller, GameEngine engine) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (engine.isGameOver)
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${engine.winner?.name ?? ''} 獲勝！',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                      child: const Text('返回主畫面'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _scoreboardFor(controller),
            const SizedBox(height: 12),
            if (controller.lastMessage != null) ...[
              Text(controller.lastMessage!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ThrowHistoryList(currentTurnThrows: engine.currentTurnThrows),
                if (controller.isCalibrated)
                  Row(
                    children: [
                      const Text('自動辨識'),
                      Switch(
                        value: controller.autoDetectEnabled,
                        onChanged: (v) {
                          controller.setAutoDetect(v);
                          _syncImageStream(v);
                        },
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: engine.history.isEmpty ? null : controller.undo,
                    icon: const Icon(Icons.undo),
                    label: const Text('復原上一鏢'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: controller.nextPlayer,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('下一位'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _scoreboardFor(GameController controller) {
    if (controller.x01 != null) return X01Scoreboard(engine: controller.x01!);
    if (controller.cricket != null) return CricketScoreboard(engine: controller.cricket!);
    if (controller.atc != null) return AtcScoreboard(engine: controller.atc!);
    return const SizedBox.shrink();
  }

  Future<void> _confirmEndGame(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('結束遊戲？'),
        content: const Text('目前的比分將不會保留。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('結束')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<GameController>().endGame();
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }
}

/// Live readout of [DartLandingDetector]'s internal state while
/// auto-detect is on — a diagnostic aid, not something a player needs
/// day to day. If "動態" never drops near 0, the picture never reads as
/// "still" (usually handheld shake, autofocus, or flickering light) and
/// a landing will never be confirmed; if "等待偵測到大動作" never
/// changes even when a dart is thrown, no motion big enough is being
/// seen at all (try a wider frame, or check the camera preview itself
/// looks right).
class _AutoDetectDebugBanner extends StatelessWidget {
  final ValueListenable<DartLandingDebugState?> debugState;

  const _AutoDetectDebugBanner({required this.debugState});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DartLandingDebugState?>(
      valueListenable: debugState,
      builder: (context, state, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            state?.toString() ?? '等待相機畫面…',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        );
      },
    );
  }
}
