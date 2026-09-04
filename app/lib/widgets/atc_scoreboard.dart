import 'package:dart_scoring_core/dart_scoring_core.dart';
import 'package:flutter/material.dart';

/// Progress board for Around the Clock.
class AtcScoreboard extends StatelessWidget {
  final AroundTheClockEngine engine;

  const AtcScoreboard({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < engine.players.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: i == engine.currentPlayerIndex && !engine.isGameOver
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: Text(engine.players[i].name, style: theme.textTheme.titleMedium)),
                Text(
                  '目標: ${_label(engine.currentTargetFor(engine.players[i].id))}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: 12),
                Text('${engine.progressFor(engine.players[i].id)}/21'),
                if (engine.winner == engine.players[i]) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                ],
              ],
            ),
          ),
      ],
    );
  }

  String _label(int target) => target == 25 ? 'BULL' : '$target';
}
