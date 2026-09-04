import '../board/dart_hit.dart';

/// One dart, as recorded into the game log — who threw it, what it hit,
/// how it was captured, and what happened as a result (useful for the
/// scoreboard UI and for undo).
class RecordedThrow {
  final String playerId;
  final DartHit hit;
  final int turnNumber;
  final int dartIndexInTurn; // 0, 1, 2

  /// Points this dart actually counted for, after mode-specific rules
  /// (e.g. 0 on a Cricket number nobody has left open, or 0 on a bust).
  final int pointsScored;
  final bool autoDetected;
  final bool wasBust;
  final DateTime timestamp;

  RecordedThrow({
    required this.playerId,
    required this.hit,
    required this.turnNumber,
    required this.dartIndexInTurn,
    required this.pointsScored,
    required this.autoDetected,
    this.wasBust = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
