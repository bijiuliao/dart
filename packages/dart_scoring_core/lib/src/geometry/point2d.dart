/// A simple immutable 2D point. Used both for pixel coordinates (image
/// space) and millimetre coordinates (board plane space) — callers keep
/// track of which space a given [Point2D] lives in.
class Point2D {
  final double x;
  final double y;

  const Point2D(this.x, this.y);

  @override
  String toString() => 'Point2D(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) =>
      other is Point2D && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
