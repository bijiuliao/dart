import 'dart:math' as math;

import 'point2d.dart';

/// A row-major 3x3 matrix used for homogeneous 2D transforms.
class Matrix3 {
  /// Row-major: `[a b c, d e f, g h i]`.
  final List<double> m;

  const Matrix3(this.m);

  factory Matrix3.identity() =>
      const Matrix3([1, 0, 0, 0, 1, 0, 0, 0, 1]);

  /// Applies this matrix to [p] as a homogeneous point `(x, y, 1)` and
  /// perspective-divides the result. Returns `(NaN, NaN)` if the point
  /// maps to infinity (denominator ~ 0).
  Point2D transform(Point2D p) {
    final x = p.x, y = p.y;
    final u = m[0] * x + m[1] * y + m[2];
    final v = m[3] * x + m[4] * y + m[5];
    final w = m[6] * x + m[7] * y + m[8];
    if (w.abs() < 1e-12) return const Point2D(double.nan, double.nan);
    return Point2D(u / w, v / w);
  }

  double get determinant {
    final a = m[0], b = m[1], c = m[2];
    final d = m[3], e = m[4], f = m[5];
    final g = m[6], h = m[7], i = m[8];
    return a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
  }

  /// Standard cofactor/adjugate inverse. Throws [StateError] if the matrix
  /// is (numerically) singular.
  Matrix3 inverse() {
    final det = determinant;
    if (det.abs() < 1e-12) {
      throw StateError('Matrix3 is singular and cannot be inverted');
    }
    final a = m[0], b = m[1], c = m[2];
    final d = m[3], e = m[4], f = m[5];
    final g = m[6], h = m[7], i = m[8];
    final invDet = 1.0 / det;
    // Adjugate = transpose of the cofactor matrix, scaled by 1/det.
    final adjT = [
      (e * i - f * h), -(b * i - c * h), (b * f - c * e),
      -(d * i - f * g), (a * i - c * g), -(a * f - c * d),
      (d * h - e * g), -(a * h - b * g), (a * e - b * d),
    ];
    return Matrix3([
      for (final v in adjT) v * invDet,
    ]);
  }
}

/// Solves the dense linear system `A x = b` via Gaussian elimination with
/// partial pivoting. `A` is square (n x n), `b` has length n. Returns the
/// solution vector `x`.
List<double> solveLinearSystem(List<List<double>> a, List<double> b) {
  final n = b.length;
  // Work on copies so callers' data isn't mutated.
  final matrix = [for (final row in a) List<double>.from(row)];
  final rhs = List<double>.from(b);

  for (var col = 0; col < n; col++) {
    // Partial pivot: find the row with the largest absolute value in this
    // column to improve numerical stability.
    var pivotRow = col;
    var pivotVal = matrix[col][col].abs();
    for (var row = col + 1; row < n; row++) {
      final v = matrix[row][col].abs();
      if (v > pivotVal) {
        pivotVal = v;
        pivotRow = row;
      }
    }
    if (pivotVal < 1e-12) {
      throw StateError('Linear system is singular or ill-conditioned');
    }
    if (pivotRow != col) {
      final tmpRow = matrix[col];
      matrix[col] = matrix[pivotRow];
      matrix[pivotRow] = tmpRow;
      final tmpVal = rhs[col];
      rhs[col] = rhs[pivotRow];
      rhs[pivotRow] = tmpVal;
    }

    final pivot = matrix[col][col];
    for (var row = col + 1; row < n; row++) {
      final factor = matrix[row][col] / pivot;
      if (factor == 0) continue;
      for (var k = col; k < n; k++) {
        matrix[row][k] -= factor * matrix[col][k];
      }
      rhs[row] -= factor * rhs[col];
    }
  }

  // Back-substitution.
  final x = List<double>.filled(n, 0);
  for (var row = n - 1; row >= 0; row--) {
    var sum = rhs[row];
    for (var col = row + 1; col < n; col++) {
      sum -= matrix[row][col] * x[col];
    }
    x[row] = sum / matrix[row][row];
  }
  return x;
}

/// A planar homography (projective transform) between two 2D coordinate
/// systems, e.g. camera image pixels <-> dartboard-plane millimetres.
///
/// Fitted from point correspondences with the Direct Linear Transform
/// (DLT). With exactly 4 correspondences the fit is exact (assuming they
/// are non-degenerate); with more than 4 it is a least-squares fit, which
/// is useful if the calibration UI lets a player tap extra reference
/// points to average out tapping error.
class Homography {
  final Matrix3 forward; // src -> dst
  final Matrix3 backward; // dst -> src

  Homography._(this.forward, this.backward);

  factory Homography.fromMatrix(Matrix3 forward) {
    return Homography._(forward, forward.inverse());
  }

  factory Homography.fromPointCorrespondences({
    required List<Point2D> src,
    required List<Point2D> dst,
  }) {
    if (src.length != dst.length) {
      throw ArgumentError('src and dst must have the same length');
    }
    if (src.length < 4) {
      throw ArgumentError(
          'At least 4 point correspondences are required, got ${src.length}');
    }

    final n = src.length;
    // Build the 2n x 8 system for h = [h0..h7] (h8 fixed to 1), then solve
    // via normal equations A^T A h = A^T b so any n >= 4 works.
    final rows = <List<double>>[];
    final rhs = <double>[];
    for (var i = 0; i < n; i++) {
      final x = src[i].x, y = src[i].y;
      final u = dst[i].x, v = dst[i].y;
      rows.add([x, y, 1, 0, 0, 0, -x * u, -y * u]);
      rhs.add(u);
      rows.add([0, 0, 0, x, y, 1, -x * v, -y * v]);
      rhs.add(v);
    }

    const k = 8;
    final ata = List.generate(k, (_) => List<double>.filled(k, 0));
    final atb = List<double>.filled(k, 0);
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var i = 0; i < k; i++) {
        atb[i] += row[i] * rhs[r];
        for (var j = 0; j < k; j++) {
          ata[i][j] += row[i] * row[j];
        }
      }
    }

    final h = solveLinearSystem(ata, atb);
    final forward = Matrix3([h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], 1]);
    return Homography.fromMatrix(forward);
  }

  Point2D apply(Point2D p) => forward.transform(p);
  Point2D applyInverse(Point2D p) => backward.transform(p);
}

/// Euclidean distance helper, used by calibration UIs and tests.
double distance(Point2D a, Point2D b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}
