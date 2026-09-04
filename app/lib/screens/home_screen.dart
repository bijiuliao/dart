import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_controller.dart';
import 'new_game_screen.dart';
import 'scoring_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    return Scaffold(
      appBar: AppBar(title: const Text('飛鏢計分')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.adjust, size: 96, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                '用手機鏡頭對準飛鏢盤，自動幫你計分',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 32),
              if (controller.hasActiveGame)
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ScoringScreen()),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('繼續目前的比賽'),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewGameScreen()),
                ),
                icon: const Icon(Icons.add),
                label: const Text('開始新遊戲'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
