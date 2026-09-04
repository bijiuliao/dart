import 'package:dart_scoring_core/dart_scoring_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_controller.dart';
import '../state/game_setup.dart';
import 'calibration_screen.dart';

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({super.key});

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  GameModeType _mode = GameModeType.x01;
  final List<TextEditingController> _nameControllers = [
    TextEditingController(text: 'Player 1'),
    TextEditingController(text: 'Player 2'),
  ];

  int _x01Score = 501;
  X01OutMode _outMode = X01OutMode.doubleOut;
  X01InMode _inMode = X01InMode.straight;
  CricketScoringMode _cricketMode = CricketScoringMode.standard;
  bool _atcRequireDouble = false;
  bool _autoDetect = false;

  static const _maxPlayers = 8;

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPlayer() {
    if (_nameControllers.length >= _maxPlayers) return;
    setState(() =>
        _nameControllers.add(TextEditingController(text: 'Player ${_nameControllers.length + 1}')));
  }

  void _removePlayer(int index) {
    if (_nameControllers.length <= 1) return;
    setState(() => _nameControllers.removeAt(index).dispose());
  }

  void _start() {
    final setup = GameSetup(
      mode: _mode,
      playerNames: [for (final c in _nameControllers) c.text],
      x01StartingScore: _x01Score,
      x01OutMode: _outMode,
      x01InMode: _inMode,
      cricketMode: _cricketMode,
      atcRequireDouble: _atcRequireDouble,
      autoDetectEnabled: _autoDetect,
    );
    context.read<GameController>().startGame(setup);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CalibrationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新遊戲')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('遊戲模式', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<GameModeType>(
            segments: const [
              ButtonSegment(value: GameModeType.x01, label: Text('01 倒扣')),
              ButtonSegment(value: GameModeType.cricket, label: Text('Cricket 占地盤')),
              ButtonSegment(value: GameModeType.aroundTheClock, label: Text('Around the Clock')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 24),
          _buildModeOptions(),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('玩家', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: _nameControllers.length >= _maxPlayers ? null : _addPlayer,
                icon: const Icon(Icons.person_add),
                label: const Text('新增玩家'),
              ),
            ],
          ),
          for (var i = 0; i < _nameControllers.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameControllers[i],
                      decoration: InputDecoration(
                        labelText: '玩家 ${i + 1}',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_nameControllers.length > 1)
                    IconButton(
                      onPressed: () => _removePlayer(i),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('自動辨識飛鏢落點'),
            subtitle: const Text('開啟後鏡頭會嘗試自動偵測飛鏢；仍可隨時手動修正或補登，建議先用固定腳架並在校準畫面確認對齊。'),
            value: _autoDetect,
            onChanged: (v) => setState(() => _autoDetect = v),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _start,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('下一步：校準相機'),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOptions() {
    switch (_mode) {
      case GameModeType.x01:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('起始分數'),
            Wrap(
              spacing: 8,
              children: [301, 501, 701].map((score) {
                return ChoiceChip(
                  label: Text('$score'),
                  selected: _x01Score == score,
                  onSelected: (_) => setState(() => _x01Score = score),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text('收尾規則（Out）'),
            SegmentedButton<X01OutMode>(
              segments: const [
                ButtonSegment(value: X01OutMode.straight, label: Text('任意收尾')),
                ButtonSegment(value: X01OutMode.doubleOut, label: Text('雙倍收尾')),
                ButtonSegment(value: X01OutMode.masterOut, label: Text('雙/三倍收尾')),
              ],
              selected: {_outMode},
              onSelectionChanged: (s) => setState(() => _outMode = s.first),
            ),
            const SizedBox(height: 12),
            const Text('開分規則（In）'),
            SegmentedButton<X01InMode>(
              segments: const [
                ButtonSegment(value: X01InMode.straight, label: Text('任意開分')),
                ButtonSegment(value: X01InMode.doubleIn, label: Text('雙倍開分')),
                ButtonSegment(value: X01InMode.masterIn, label: Text('雙/三倍開分')),
              ],
              selected: {_inMode},
              onSelectionChanged: (s) => setState(() => _inMode = s.first),
            ),
          ],
        );
      case GameModeType.cricket:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('計分方式'),
            SegmentedButton<CricketScoringMode>(
              segments: const [
                ButtonSegment(value: CricketScoringMode.standard, label: Text('標準')),
                ButtonSegment(value: CricketScoringMode.cutThroat, label: Text('Cut-throat')),
                ButtonSegment(value: CricketScoringMode.noScore, label: Text('不計分')),
              ],
              selected: {_cricketMode},
              onSelectionChanged: (s) => setState(() => _cricketMode = s.first),
            ),
          ],
        );
      case GameModeType.aroundTheClock:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('進階：需擊中雙倍環才能過關'),
          value: _atcRequireDouble,
          onChanged: (v) => setState(() => _atcRequireDouble = v),
        );
    }
  }
}
