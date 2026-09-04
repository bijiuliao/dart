import 'package:dart_scoring_core/dart_scoring_core.dart';
import 'package:flutter/material.dart';

/// The current turn's darts (0-3), shown as chips so the player can see
/// at a glance what's been recorded before the turn auto-advances.
class ThrowHistoryList extends StatelessWidget {
  final List<RecordedThrow> currentTurnThrows;

  const ThrowHistoryList({super.key, required this.currentTurnThrows});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _DartSlot(recorded: i < currentTurnThrows.length ? currentTurnThrows[i] : null),
        ],
      ],
    );
  }
}

class _DartSlot extends StatelessWidget {
  final RecordedThrow? recorded;
  const _DartSlot({required this.recorded});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hit = recorded?.hit;
    return Container(
      width: 56,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hit == null
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        hit?.label ?? '-',
        style: theme.textTheme.titleSmall?.copyWith(
          color: recorded?.wasBust == true ? theme.colorScheme.error : null,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
