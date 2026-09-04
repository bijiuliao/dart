/// A player in a game. Immutable identity/name; all mutable game state
/// (score, marks, etc.) lives in the game engine, keyed by [id].
class Player {
  final String id;
  final String name;

  const Player({required this.id, required this.name});

  @override
  String toString() => 'Player($name)';

  @override
  bool operator ==(Object other) => other is Player && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
