/// The four regional leaderboards, in addition to the National board.
/// The string in Firestore (school docs' `region` field, student profiles'
/// `region` field, and license codes' `region` field) is always
/// [GameRegion.id] — stable, lowercase, never renamed even if [label]
/// wording changes later.
enum GameRegion { west, south, north, east }

extension GameRegionX on GameRegion {
  /// Stable Firestore value. Do not change once data exists using it.
  String get id => name;

  String get label {
    switch (this) {
      case GameRegion.west:
        return 'West Coast';
      case GameRegion.south:
        return 'South Coast';
      case GameRegion.north:
        return 'North Coast';
      case GameRegion.east:
        return 'East Coast';
    }
  }

  String get emoji {
    switch (this) {
      case GameRegion.west:
        return '🌅';
      case GameRegion.south:
        return '🌴';
      case GameRegion.north:
        return '🌲';
      case GameRegion.east:
        return '🗽';
    }
  }
}

/// Parses a Firestore `region` string back into a [GameRegion], or null if
/// it's missing/unrecognized (e.g. a school that hasn't been assigned a
/// region yet -- such schools still show up on the National board, just not
/// under any regional tab).
GameRegion? gameRegionFromId(String? id) {
  if (id == null) return null;
  for (final r in GameRegion.values) {
    if (r.id == id) return r;
  }
  return null;
}
