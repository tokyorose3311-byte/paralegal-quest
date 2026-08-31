import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/region.dart';
import '../models/student_profile.dart';
import 'pilot_code_service.dart';

/// Real, cross-device individual player accounts for students -- backed by
/// Firebase Authentication (email/password) plus a `students/{uid}` profile
/// document in Firestore for stats (points/correct/games/wins), school, and
/// region.
///
/// This replaces the old "type your name at setup" identity model, where
/// two different students both entering "Maria" at the same school would
/// silently merge into a single record. With real accounts, identity is the
/// signed-in Firebase uid -- stable across devices, never collides between
/// students, and never requires an app update to add.
///
/// Playing without an account (the free demo / local-only mode) still works
/// exactly as before -- this is purely additive.
class StudentAuthService {
  final _auth = FirebaseAuth.instance;
  final _col = FirebaseFirestore.instance.collection('students');
  final _pilotCodes = PilotCodeService();

  // Same 12-second timeout convention used for the Auth calls below --
  // applied to every Firestore read/write here too, so a stalled websocket
  // (flaky wifi, a proxy, an ad-blocker) can never hang an `await`
  // indefinitely with no exception ever thrown. An un-timed-out hang here
  // is invisible to try/catch and looks exactly like a frozen game/screen.
  static const _kNetworkTimeout = Duration(seconds: 12);

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Creates a brand-new student account (Firebase Auth user + Firestore
  /// profile doc) and returns null on success, or a user-facing error
  /// string on failure.
  ///
  /// [pilotCode] is REQUIRED -- Individual Pilot access is a $20 paid,
  /// promotional beta ("give us feedback") program. The code is issued
  /// manually by an admin after seeing a Stripe payment come in (Option A:
  /// no automated webhook for this collection). The code is validated and
  /// atomically marked as used BEFORE the Firebase Auth account is created,
  /// so a bad/already-used code never leaves behind an orphaned auth user
  /// with no valid code attached.
  Future<String?> register({
    required String email,
    required String password,
    required String displayName,
    required String school,
    required GameRegion? region,
    required String pilotCode,
  }) async {
    // 1. Validate + redeem the pilot code first. We don't yet have a uid to
    // tie it to, so we do a lightweight existence/unused check here, then
    // do the real atomic redeem (tied to the new uid) right after account
    // creation. This order still guarantees no auth account is created for
    // an obviously bad code, while the final atomic step (below) is what
    // actually prevents a race between two students using the same code.
    final precheck = await _pilotCodes.peek(pilotCode);
    if (precheck == null) {
      return 'That pilot code was not recognized. Double-check it and try again.';
    }
    if (precheck.used) {
      return 'That pilot code has already been used. Contact us if this seems wrong.';
    }

    try {
      final cred = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(const Duration(seconds: 12));
      final uid = cred.user?.uid;
      if (uid == null) return 'Account creation failed. Please try again.';

      // 2. Atomically redeem the code now that we have a real uid. If this
      // fails (e.g. someone else redeemed it in the split second between
      // our precheck and now), roll back the just-created auth account so
      // we never leave an orphaned account with no valid code.
      final redeemError = await _pilotCodes.redeem(
        rawCode: pilotCode,
        uid: uid,
        email: email.trim(),
      );
      if (redeemError != null) {
        try {
          await cred.user?.delete();
        } catch (_) {
          // Best-effort rollback -- if it fails, an orphaned auth account
          // with no student profile is harmless (it just can't sign in
          // usefully anywhere, and can be cleaned up from Firebase Console).
        }
        return redeemError;
      }

      final profile = StudentProfile(
        uid: uid,
        displayName: displayName.trim().isEmpty
            ? 'Student'
            : displayName.trim(),
        email: email.trim(),
        school: school.trim(),
        region: region,
      );
      await _col.doc(uid).set(profile.toCreateMap());
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'An account already exists for that email. Try signing in instead.';
        case 'weak-password':
          return 'Password is too weak -- use at least 6 characters.';
        case 'invalid-email':
          return 'That email address looks invalid.';
        default:
          return 'Could not create account: ${e.message}';
      }
    } on TimeoutException {
      return 'Could not reach the server (network is too slow or blocked). Try again.';
    } catch (e) {
      return 'Could not create account: $e';
    }
  }

  /// Signs an existing student in. Returns null on success, or a
  /// user-facing error string on failure.
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth
          .signInWithEmailAndPassword(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 12));
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        default:
          return 'Sign-in failed: ${e.message}';
      }
    } on TimeoutException {
      return 'Could not reach the server (network is too slow or blocked). Try again.';
    } catch (e) {
      return 'Sign-in failed: $e';
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Fetches the signed-in student's profile, or null if not signed in / no
  /// profile doc exists yet (defensive -- shouldn't normally happen since
  /// [register] always creates one).
  Future<StudentProfile?> getMyProfile() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final doc = await _col.doc(uid).get().timeout(_kNetworkTimeout);
    if (!doc.exists) return null;
    return StudentProfile.fromDoc(uid, doc.data()!);
  }

  /// Updates editable profile fields (school/region/display name). Stats
  /// fields are never written from here -- see [recordGameResult].
  Future<void> updateProfile({
    String? displayName,
    String? school,
    GameRegion? region,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    final update = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (displayName != null) update['displayName'] = displayName.trim();
    if (school != null) update['school'] = school.trim();
    if (region != null) update['region'] = region.id;
    await _col
        .doc(uid)
        .set(update, SetOptions(merge: true))
        .timeout(_kNetworkTimeout);
  }

  /// Atomically increments the signed-in student's stats after a game ends.
  /// Uses FieldValue.increment so concurrent games from the same account on
  /// different devices never clobber each other's totals.
  Future<void> recordGameResult({
    required int pointsEarned,
    required int correctEarned,
    required bool won,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _col
        .doc(uid)
        .set({
          'points': FieldValue.increment(pointsEarned),
          'correct': FieldValue.increment(correctEarned),
          'games': FieldValue.increment(1),
          'wins': FieldValue.increment(won ? 1 : 0),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .timeout(_kNetworkTimeout);
  }

  /// Top individual students, nation-wide, ranked by points descending.
  /// Simple unfiltered fetch + in-memory sort/limit -- consistent with this
  /// project's convention of avoiding composite-index dependencies.
  Future<List<StudentProfile>> topStudents({int limit = 20}) async {
    final snap = await _col.get().timeout(_kNetworkTimeout);
    final list = snap.docs
        .map((d) => StudentProfile.fromDoc(d.id, d.data()))
        .toList();
    list.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      return b.correct.compareTo(a.correct);
    });
    return list.take(limit).toList();
  }

  /// Top individual students within a single region, ranked by points
  /// descending. Filters in memory after a simple `where` query (no
  /// `orderBy`) to avoid needing a composite Firestore index.
  Future<List<StudentProfile>> topStudentsInRegion(
    GameRegion region, {
    int limit = 20,
  }) async {
    final snap = await _col
        .where('region', isEqualTo: region.id)
        .get()
        .timeout(_kNetworkTimeout);
    final list = snap.docs
        .map((d) => StudentProfile.fromDoc(d.id, d.data()))
        .toList();
    list.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      return b.correct.compareTo(a.correct);
    });
    return list.take(limit).toList();
  }

  /// Total number of student accounts currently on the individual
  /// leaderboard (nation-wide). Used purely for the "N students ranked
  /// nationally" counter shown to signed-out players -- makes clear that
  /// signing in is about joining a real, populated leaderboard, not about
  /// unlocking access to play the game.
  Future<int> totalRankedCount() async {
    final snap = await _col.get().timeout(_kNetworkTimeout);
    return snap.docs.length;
  }

  /// The signed-in student's current nation-wide rank (1 = top), or null if
  /// not signed in or their profile doc isn't found in the fetched list
  /// (e.g. a very brief window right after registration before it syncs).
  /// Same in-memory sort as [topStudents] so the rank always matches what
  /// the leaderboard screen itself would show.
  Future<int?> myRank() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final snap = await _col.get().timeout(_kNetworkTimeout);
    final list = snap.docs
        .map((d) => StudentProfile.fromDoc(d.id, d.data()))
        .toList();
    list.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      return b.correct.compareTo(a.correct);
    });
    final idx = list.indexWhere((p) => p.uid == uid);
    return idx == -1 ? null : idx + 1;
  }
}
