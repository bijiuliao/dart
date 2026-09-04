/// Pure-Dart core: dartboard geometry/scoring, image<->board homography,
/// and rule engines for X01, Cricket and Around the Clock. No Flutter
/// dependency — safe to unit test with the plain Dart SDK and reused by
/// the mobile app for both camera-driven and manual scoring.
library dart_scoring_core;

export 'src/geometry/point2d.dart';
export 'src/geometry/homography.dart';

export 'src/board/dart_hit.dart';
export 'src/board/board_geometry.dart';

export 'src/game/player.dart';
export 'src/game/recorded_throw.dart';
export 'src/game/game_engine.dart';
export 'src/game/x01/x01_engine.dart';
export 'src/game/cricket/cricket_engine.dart';
export 'src/game/atc/around_the_clock_engine.dart';
