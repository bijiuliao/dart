import 'package:camera/camera.dart';
import 'package:dart_scoring_core/dart_scoring_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../camera/board_overlay_painter.dart';
import '../state/game_controller.dart';
import 'scoring_screen.dart';

/// Lines up the live camera preview with the real dartboard: the player
/// taps the outer edge of the double ring at four reference points (over
/// the 20, 6, 3 and 11 sectors), which is enough to fit a full
/// perspective (not just scale/rotate) mapping even if the phone isn't
/// perfectly square-on to the board. See [Homography].
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  CameraController? _controller;
  String? _error;
  final List<Offset> _tapped = [];

  static const _instructions = [
    '請點選「20」外側雙倍環邊緣（畫面上方）',
    '請點選「6」外側雙倍環邊緣（畫面右方）',
    '請點選「3」外側雙倍環邊緣（畫面下方）',
    '請點選「11」外側雙倍環邊緣（畫面左方）',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = '找不到可用的相機');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '無法開啟相機：$e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    if (_tapped.length >= 4) return;
    setState(() => _tapped.add(details.localPosition));
    if (_tapped.length == 4) _finishCalibration();
  }

  void _finishCalibration() {
    final homography = Homography.fromPointCorrespondences(
      src: BoardGeometry.defaultCalibrationPoints,
      dst: [for (final p in _tapped) Point2D(p.dx, p.dy)],
    );
    context.read<GameController>().setCalibration(homography);
  }

  void _reset() {
    setState(() => _tapped.clear());
    context.read<GameController>().clearCalibration();
  }

  void _goToScoring() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ScoringScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();

    return Scaffold(
      appBar: AppBar(title: const Text('校準相機')),
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              )
            : (_controller == null || !_controller!.value.isInitialized)
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: GestureDetector(
                              onTapDown: _handleTap,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(_controller!),
                                  CustomPaint(
                                    painter: CalibrationPointsPainter(tappedPoints: _tapped),
                                  ),
                                  if (controller.isCalibrated)
                                    CustomPaint(
                                      painter: BoardWireframePainter(
                                        calibration: controller.calibration!,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              controller.isCalibrated
                                  ? '校準完成！請確認上方輪廓與真實飛鏢盤是否對齊。'
                                  : _instructions[_tapped.length],
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              children: [
                                if (_tapped.isNotEmpty)
                                  OutlinedButton(onPressed: _reset, child: const Text('重新點選')),
                                if (controller.isCalibrated)
                                  FilledButton(onPressed: _goToScoring, child: const Text('開始比賽'))
                                else
                                  TextButton(
                                    onPressed: _goToScoring,
                                    child: const Text('略過校準，改用手動計分'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
