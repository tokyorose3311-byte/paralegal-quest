import 'package:cloud_firestore/cloud_firestore.dart';
import 'region.dart';

/// A real, cross-device individual player account, stored in the
/// Firestore `students/{uid}` collection (uid == Firebase Auth uid).
///
/// Unlike the old "type your name at setup" system -- where two different
/// students both typing "Maria" at the same school silently merged into one
/// record -- every account here is tied to a unique, authenticated Firebase
/// user, so stats never collide between students and follow a given
/// student across any device they sign in on.
class StudentProfile {
  final String uid;
  final String displayName;
  final String email;
  final String school;
  final GameRegion? region;
  final int points;
  final int correct;
  final int games;
  final int wins;

  const StudentProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.school,
    required this.region,
    this.points = 0,
    this.correct = 0,
    this.games = 0,
    this.wins = 0,
  });

  factory StudentProfile.fromDoc(String uid, Map<String, dynamic> d) {
    return StudentProfile(
      uid: uid,
      displayName: (d['displayName'] as String?) ?? 'Student',
      email: (d['email'] as String?) ?? '',
      school: (d['school'] as String?) ?? '',
      region: gameRegionFromId(d['region'] as String?),
      points: (d['points'] as num?)?.toInt() ?? 0,
      correct: (d['correct'] as num?)?.toInt() ?? 0,
      games: (d['games'] as num?)?.toInt() ?? 0,
      wins: (d['wins'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toCreateMap() => {
    'displayName': displayName,
    'email': email,
    'school': school,
    'region': region?.id,
    'points': 0,
    'correct': 0,
    'games': 0,
    'wins': 0,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  StudentProfile copyWith({
    String? displayName,
    String? school,
    GameRegion? region,
    int? points,
    int? correct,
    int? games,
    int? wins,
  }) => StudentProfile(
    uid: uid,
    displayName: displayName ?? this.displayName,
    email: email,
    school: school ?? this.school,
    region: region ?? this.region,
    points: points ?? this.points,
    correct: correct ?? this.correct,
    games: games ?? this.games,
    wins: wins ?? this.wins,
  );
}
