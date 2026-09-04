import 'package:dart_scoring_core/dart_scoring_core.dart';
import 'package:flutter/material.dart';

/// Remaining-score board for 501/301/701 ("倒扣") games.
class X01Scoreboard extends StatelessWidget {
  final X01Engine engine;

  const X01Scoreboard({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < engine.players.length; i++)
          _PlayerRow(
            player: engine.players[i],
            remaining: engine.remainingScore(engine.players[i].id),
            isCurrent: i == engine.currentPlayerIndex && !engine.isGameOver,
            hasOpened: engine.hasOpened(engine.players[i].id),
            isWinner: engine.winner == engine.players[i],
          ),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final Player player;
  final int remaining;
  final bool isCurrent;
  final bool hasOpened;
  final bool isWinner;

  const _PlayerRow({
    required this.player,
    required this.remaining,
    required this.isCurrent,
    required this.hasOpened,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(player.name, style: theme.textTheme.titleMedium),
                if (isWinner) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                ],
                if (!hasOpened) ...[
                  const SizedBox(width: 6),
                  Text('(未開分)', style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          Text(
            '$remaining',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isCurrent ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
