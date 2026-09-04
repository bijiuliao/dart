import 'package:dart_scoring_core/dart_scoring_core.dart';
import 'package:flutter/material.dart';

/// Marks/points board for Cricket ("占地盤") games.
class CricketScoreboard extends StatelessWidget {
  final CricketEngine engine;

  const CricketScoreboard({super.key, required this.engine});

  static const _columns = [20, 19, 18, 17, 16, 15, 25];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 44,
        columns: [
          const DataColumn(label: Text('')),
          for (final c in _columns) DataColumn(label: Text(c == 25 ? 'Bull' : '$c')),
          const DataColumn(label: Text('分數')),
        ],
        rows: [
          for (var i = 0; i < engine.players.length; i++)
            DataRow(
              color: i == engine.currentPlayerIndex && !engine.isGameOver
                  ? WidgetStateProperty.all(theme.colorScheme.primaryContainer)
                  : null,
              cells: [
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(engine.players[i].name),
                  if (engine.winner == engine.players[i])
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                    ),
                ])),
                for (final c in _columns)
                  DataCell(_MarksGlyph(marks: engine.marksFor(engine.players[i].id, c))),
                DataCell(Text('${engine.pointsFor(engine.players[i].id)}')),
              ],
            ),
        ],
      ),
    );
  }
}

class _MarksGlyph extends StatelessWidget {
  final int marks;
  const _MarksGlyph({required this.marks});

  @override
  Widget build(BuildContext context) {
    final glyph = switch (marks) {
      0 => '',
      1 => '/',
      2 => 'X',
      _ => '⊗',
    };
    return SizedBox(
      width: 24,
      child: Text(
        glyph,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}
