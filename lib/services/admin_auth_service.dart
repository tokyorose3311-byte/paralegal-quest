import 'package:firebase_auth/firebase_auth.dart';

/// Real Firebase Authentication for the admin back-office.
/// Replaces the old hardcoded email/password constants that lived in the
/// client bundle (visible to anyone who inspected the app).
///
/// To create your admin account:
///  1. Firebase Console -> Build -> Authentication -> Get started
///  2. Enable the "Email/Password" sign-in provider
///  3. Go to the "Users" tab -> "Add user" -> enter your email + a password
/// That's it — sign in with those credentials in the app's Admin screen.
class AdminAuthService {
  final _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // success
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
    } catch (e) {
      return 'Sign-in failed: $e';
    }
  }

  Future<void> signOut() => _auth.signOut();
}
