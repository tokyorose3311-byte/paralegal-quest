import 'package:cloud_firestore/cloud_firestore.dart';

/// A one-time-use "Individual Pilot — $20" access code.
///
/// This is Option A of the individual-account paywall: fully manual.
/// A student pays $20 via a Stripe Payment Link, the admin sees the
/// payment notification in their own Stripe dashboard/email, then opens
/// the admin panel here and generates (or types) a code and shares it
/// with that student by email. There is NO Stripe webhook wired to this
/// collection -- unlike `license_codes` (school/classroom), which already
/// has an automated webhook (see netlify/functions/stripe-webhook.js).
///
/// Codes live in the `pilot_codes` Firestore collection, doc id == the
/// code itself (uppercased), so validation is a single cheap `.get()`.
class PilotCode {
  final String code;
  final bool used;
  final String? usedByUid;
  final String? usedByEmail;
  final String? note;

  const PilotCode({
    required this.code,
    this.used = false,
    this.usedByUid,
    this.usedByEmail,
    this.note,
  });

  factory PilotCode.fromDoc(String id, Map<String, dynamic> d) => PilotCode(
    code: id,
    used: (d['used'] as bool?) ?? false,
    usedByUid: d['used_by_uid'] as String?,
    usedByEmail: d['used_by_email'] as String?,
    note: d['note'] as String?,
  );
}

/// Cloud-backed validation & manual generation for individual pilot codes.
class PilotCodeService {
  final _col = FirebaseFirestore.instance.collection('pilot_codes');

  /// Fetches all pilot codes (for the admin panel), newest first isn't
  /// tracked separately -- sorted by code id which is fine for a small
  /// manually-curated list.
  Future<List<PilotCode>> getAll() async {
    final snap = await _col.get();
    final list = snap.docs
        .map((d) => PilotCode.fromDoc(d.id, d.data()))
        .toList();
    list.sort((a, b) => a.code.compareTo(b.code));
    return list;
  }

  /// Creates a brand-new, unused code (admin panel "Add code"). Overwrites
  /// silently if the same code text already exists and is unused -- lets an
  /// admin re-issue a note without clobbering a code that's already redeemed
  /// (see [redeem], which fails safely for already-used codes regardless).
  Future<void> create({required String code, String? note}) async {
    final id = code.trim().toUpperCase();
    if (id.isEmpty) return;
    await _col.doc(id).set({
      'used': false,
      'used_by_uid': null,
      'used_by_email': null,
      'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> delete(String code) async {
    await _col.doc(code.trim().toUpperCase()).delete();
  }

  /// Validates a raw code without consuming it. Returns the matching
  /// [PilotCode] if it exists, else null. Used to give immediate feedback
  /// ("Invalid code" / "Code already used") before attempting registration.
  Future<PilotCode?> peek(String rawCode) async {
    final id = rawCode.trim().toUpperCase();
    if (id.isEmpty) return null;
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return PilotCode.fromDoc(doc.id, doc.data()!);
  }

  /// Atomically validates AND marks a code as used, tying it to [uid]/
  /// [email]. Returns null on success, or a user-facing error string.
  ///
  /// Uses a Firestore transaction so two students racing to redeem the
  /// same code can never both succeed -- the second one always loses.
  Future<String?> redeem({
    required String rawCode,
    required String uid,
    required String email,
  }) async {
    final id = rawCode.trim().toUpperCase();
    if (id.isEmpty) {
      return 'Enter your pilot access code.';
    }
    final ref = _col.doc(id);
    try {
      return await FirebaseFirestore.instance.runTransaction<String?>((
        tx,
      ) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          return 'That code was not recognized. Double-check it and try again.';
        }
        final used = (snap.data()?['used'] as bool?) ?? false;
        if (used) {
          return 'That code has already been used. Contact us if this seems wrong.';
        }
        tx.update(ref, {
          'used': true,
          'used_by_uid': uid,
          'used_by_email': email,
          'used_at': FieldValue.serverTimestamp(),
        });
        return null;
      });
    } catch (e) {
      return 'Could not verify your code (network issue). Try again.';
    }
  }
}
