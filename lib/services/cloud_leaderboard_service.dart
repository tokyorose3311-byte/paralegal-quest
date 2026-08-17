import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/region.dart';
import '../utils/slug.dart';
import 'leaderboard_service.dart' show GameResult, PlayerStats;

/// A single school's aggregate standing, as read from the Firestore
/// `schools` collection. This is the REAL national/regional board -- unlike
/// the old `LeaderboardService`, which only ever wrote to on-device
/// SharedPreferences (so "national" standings were actually just
/// "whatever games happened to be played on this one phone").
class SchoolBoardEntry {
  final String id; // slugified doc id
  final String displayName;
  final GameRegion? region;
  final int points;
  final int correct;
  final int games;
  final int wins;

  const SchoolBoardEntry({
    required this.id,
    required this.displayName,
    required this.region,
    required this.points,
    required this.correct,
    required this.games,
    required this.wins,
  });

  factory SchoolBoardEntry.fromDoc(String id, Map<String, dynamic> d) {
    return SchoolBoardEntry(
      id: id,
      displayName: (d['displayName'] as String?) ?? id,
      region: gameRegionFromId(d['region'] as String?),
      points: (d['points'] as num?)?.toInt() ?? 0,
      correct: (d['correct'] as num?)?.toInt() ?? 0,
      games: (d['games'] as num?)?.toInt() ?? 0,
      wins: (d['wins'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Cloud-backed national + regional school leaderboard, stored in Firestore
/// so every device/player everywhere contributes to and sees the SAME
/// standings -- unlike the local SharedPreferences board, which never left
/// the device it was recorded on.
///
/// Schema:
///   schools/{schoolSlug}                -> displayName, region, points,
///                                          correct, games, wins, updatedAt
///   schools/{schoolSlug}/players/{slug} -> displayName, points, correct,
///                                          games, wins, updatedAt
///
/// `region` is one of [GameRegion.id] ('west'|'south'|'north'|'east') or
/// absent/null for schools that haven't been assigned one yet -- those
/// still appear on the National board, just not under any regional tab.
class CloudLeaderboardService {
  final _schools = FirebaseFirestore.instance.collection('schools');

  /// Records a batch of game results (one per player) into the cloud board.
  /// Uses FieldValue.increment so concurrent submissions from different
  /// devices/games never clobber each other's totals -- unlike a
  /// read-modify-write, this is safe even if two schools' games finish at
  /// the exact same moment.
  Future<void> submitResults(List<GameResult> results) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final r in results) {
      final schoolId = slugify(r.school);
      final schoolRef = _schools.doc(schoolId);
      final schoolUpdate = <String, dynamic>{
        'displayName': r.school,
        'points': FieldValue.increment(r.points),
        'correct': FieldValue.increment(r.correct),
        'games': FieldValue.increment(1),
        'wins': FieldValue.increment(r.win ? 1 : 0),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // Only touch `region` if this result actually carries one -- so a
      // game played without a region selected never wipes out a region
      // an admin (or an earlier game) already set for this school.
      if (r.region != null) schoolUpdate['region'] = r.region!.id;
      batch.set(schoolRef, schoolUpdate, SetOptions(merge: true));

      final playerRef = schoolRef.collection('players').doc(slugify(r.player));
      batch.set(playerRef, {
        'displayName': r.player,
        'points': FieldValue.increment(r.points),
        'correct': FieldValue.increment(r.correct),
        'games': FieldValue.increment(1),
        'wins': FieldValue.increment(r.win ? 1 : 0),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Fetches every school on the board. Simple unfiltered `get()` (no
  /// Firestore `orderBy`) -- sort/filter happens in memory in [standings],
  /// consistent with this project's convention of avoiding composite-index
  /// dependencies.
  Future<List<SchoolBoardEntry>> getAllSchools() async {
    final snap = await _schools.get();
    return snap.docs
        .map((d) => SchoolBoardEntry.fromDoc(d.id, d.data()))
        .toList();
  }

  /// Ranks schools by points (ties broken by correct-answer count, then
  /// name). Pass [region] to get that regional board; pass null for the
  /// National board (every school, regardless of region).
  List<SchoolBoardEntry> standings(
    List<SchoolBoardEntry> schools, {
    GameRegion? region,
  }) {
    final filtered = region == null
        ? schools
        : schools.where((s) => s.region == region).toList();
    filtered.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      final byCorrect = b.correct.compareTo(a.correct);
      if (byCorrect != 0) return byCorrect;
      return a.displayName.compareTo(b.displayName);
    });
    return filtered;
  }

  /// The top player (by points) within a single school -- used for the
  /// "School MVP" line. Fetched lazily/on-demand (e.g. only for the #1
  /// school shown on a given tab) rather than for every row, to keep this
  /// cheap regardless of how many schools are on the board.
  Future<PlayerStats?> topPlayerFor(String schoolId) async {
    final snap = await _schools.doc(schoolId).collection('players').get();
    if (snap.docs.isEmpty) return null;
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final ap = (a.data()['points'] as num?)?.toInt() ?? 0;
        final bp = (b.data()['points'] as num?)?.toInt() ?? 0;
        return bp.compareTo(ap);
      });
    final top = docs.first.data();
    return PlayerStats(
      points: (top['points'] as num?)?.toInt() ?? 0,
      correct: (top['correct'] as num?)?.toInt() ?? 0,
      games: (top['games'] as num?)?.toInt() ?? 0,
      wins: (top['wins'] as num?)?.toInt() ?? 0,
    );
  }

  /// The top player's display name within a single school -- paired with
  /// [topPlayerFor] for the "School MVP: Name" line.
  Future<String?> topPlayerNameFor(String schoolId) async {
    final snap = await _schools.doc(schoolId).collection('players').get();
    if (snap.docs.isEmpty) return null;
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final ap = (a.data()['points'] as num?)?.toInt() ?? 0;
        final bp = (b.data()['points'] as num?)?.toInt() ?? 0;
        return bp.compareTo(ap);
      });
    return (docs.first.data()['displayName'] as String?) ?? docs.first.id;
  }

  /// Removes a school and its per-player subcollection docs entirely
  /// (admin panel "remove school").
  Future<void> removeSchool(String schoolId) async {
    final ref = _schools.doc(schoolId);
    final players = await ref.collection('players').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final p in players.docs) {
      batch.delete(p.reference);
    }
    batch.delete(ref);
    await batch.commit();
  }

  /// Clears the ENTIRE cloud board (admin panel "start new season").
  /// Deletes every school doc and its players subcollection. Intended for
  /// occasional admin use, not hot-path gameplay.
  Future<void> clearBoard() async {
    final snap = await _schools.get();
    for (final doc in snap.docs) {
      await removeSchool(doc.id);
    }
  }

  /// Assigns/changes a school's region directly (admin panel), without
  /// requiring a new game result to carry it.
  Future<void> setSchoolRegion(String schoolId, GameRegion? region) async {
    await _schools.doc(schoolId).set({
      'region': region?.id,
    }, SetOptions(merge: true));
  }
}
