import 'package:firebase_auth/firebase_auth.dart';

/// Checks whether the currently signed-in Firebase user carries the
/// `admin: true` custom claim (set via the Admin SDK -- see
/// scripts/bulk_upload or the Firebase console for how admin accounts are
/// provisioned; never via client code).
///
/// IMPORTANT: This is intentionally NOT the same thing as "is signed in".
/// Once students can self-register accounts (see StudentAuthService), ANY
/// authenticated user satisfies `currentUser != null` -- so admin-only
/// gating (both here and in Firestore's security rules) must check this
/// claim specifically, never just presence of a signed-in user.
Future<bool> currentUserIsAdmin({bool forceRefresh = false}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  try {
    // forceRefresh defaults to false -- claims are cached on the token and
    // only change when explicitly set server-side + the token naturally
    // refreshes, so there's no need to force a network round-trip on every
    // check. Callers pass true right after a fresh sign-in, in case an
    // admin claim was granted after this token was originally minted.
    final result = await user.getIdTokenResult(forceRefresh);
    return result.claims?['admin'] == true;
  } catch (_) {
    // If the claim check fails (offline, etc.), fail closed -- never treat
    // an unverified user as admin.
    return false;
  }
}
