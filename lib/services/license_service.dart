import 'package:cloud_firestore/cloud_firestore.dart';

/// A license code record stored in Firestore.
class LicenseCode {
  final String code;
  final String school;
  final String type; // 'school' | 'classroom'
  final bool used;
  final String? customerEmail;

  LicenseCode({
    required this.code,
    required this.school,
    required this.type,
    this.used = false,
    this.customerEmail,
  });

  factory LicenseCode.fromDoc(String id, Map<String, dynamic> d) =>
      LicenseCode(
        code: id,
        school: (d['school'] as String?) ?? '',
        type: (d['type'] as String?) ?? 'classroom',
        used: (d['used'] as bool?) ?? false,
        customerEmail: d['customer_email'] as String?,
      );

  Map<String, dynamic> toMap() => {
    'school': school,
    'type': type,
    'used': used,
    'customer_email': customerEmail,
    'created_at': FieldValue.serverTimestamp(),
  };
}

/// Cloud-backed license code validation & management.
/// Every device / app install checks the SAME Firestore collection, so a
/// code generated once (e.g. after a Stripe payment) works everywhere
/// immediately without needing an app update.
class LicenseService {
  final _col = FirebaseFirestore.instance.collection('license_codes');

  /// Validates a code. Returns the matching LicenseCode if valid, else null.
  Future<LicenseCode?> validate(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return null;
    final doc = await _col.doc(code).get();
    if (!doc.exists) return null;
    return LicenseCode.fromDoc(doc.id, doc.data()!);
  }

  /// Fetches all codes (for the admin panel).
  Future<List<LicenseCode>> getAll() async {
    final snap = await _col.orderBy('__name__').get();
    return snap.docs.map((d) => LicenseCode.fromDoc(d.id, d.data())).toList();
  }

  /// Creates or overwrites a code manually (admin panel "Add code").
  Future<void> upsert({
    required String code,
    required String school,
    required String type,
  }) async {
    final id = code.trim().toUpperCase();
    await _col.doc(id).set({
      'school': school,
      'type': type,
      'used': false,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> delete(String code) async {
    await _col.doc(code.trim().toUpperCase()).delete();
  }
}
