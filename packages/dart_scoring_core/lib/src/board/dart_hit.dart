/// Which ring of the board a dart landed in.
enum DartRing { miss, single, double, triple, outerBull, innerBull }

/// The result of scoring a single dart: which ring it landed in and, for
/// the numbered wedges, which sector (1-20).
class DartHit {
  final DartRing ring;

  /// 1-20 for [DartRing.single]/[DartRing.double]/[DartRing.triple].
  /// `null` for [DartRing.miss], [DartRing.outerBull] and
  /// [DartRing.innerBull] (bulls have no sector).
  final int? sector;

  const DartHit({required this.ring, this.sector})
      : assert(
          (ring == DartRing.single ||
                  ring == DartRing.double ||
                  ring == DartRing.triple)
              ? sector != null
              : sector == null,
          'sector must be set for single/double/triple hits only',
        );

  const DartHit.miss()
      : ring = DartRing.miss,
        sector = null;

  const DartHit.innerBull()
      : ring = DartRing.innerBull,
        sector = null;

  const DartHit.outerBull()
      : ring = DartRing.outerBull,
        sector = null;

  /// Convenience for a numbered-wedge hit, e.g.
  /// `DartHit.sectorHit(ring: DartRing.triple, sector: 20)` for T20.
  const DartHit.sectorHit({required this.ring, required this.sector});

  int get multiplier => switch (ring) {
        DartRing.triple => 3,
        DartRing.double => 2,
        _ => 1,
      };

  /// Points this single dart is worth (before any game-mode-specific
  /// rules like Cricket marks or X01 bust logic are applied).
  int get points => switch (ring) {
        DartRing.miss => 0,
        DartRing.outerBull => 25,
        DartRing.innerBull => 50,
        DartRing.single ||
        DartRing.double ||
        DartRing.triple =>
          (sector ?? 0) * multiplier,
      };

  /// Whether this hit counts as a "double" for double-out / double-in
  /// purposes. By common convention the bullseye (50) counts as a double
  /// (it's "double 25").
  bool get countsAsDouble => ring == DartRing.double || ring == DartRing.innerBull;

  /// Whether this hit counts as a "master" (double or triple) for
  /// master-out rules.
  bool get countsAsMaster =>
      countsAsDouble || ring == DartRing.triple;

  String get label => switch (ring) {
        DartRing.miss => 'MISS',
        DartRing.outerBull => '25',
        DartRing.innerBull => 'BULL',
        DartRing.single => 'S$sector',
        DartRing.double => 'D$sector',
        DartRing.triple => 'T$sector',
      };

  @override
  String toString() => 'DartHit($label, ${points}pts)';

  @override
  bool operator ==(Object other) =>
      other is DartHit && other.ring == ring && other.sector == sector;

  @override
  int get hashCode => Object.hash(ring, sector);
}
