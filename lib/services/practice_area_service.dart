import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/practice_area.dart';

/// Cloud-backed practice-area menu. The setup screen's "Choose your
/// practice area" tiles (and their active/locked state) are driven entirely
/// by documents in this collection, so unlocking a new practice area (e.g.
/// Estate Law) is just flipping `active: true` on its document -- via the
/// Admin panel toggle, or directly in the Firebase console -- with no app
/// rebuild or Play Store resubmission needed.
///
/// This is a separate collection from `questions` (see QuestionService) and
/// does not change how `bulk_upload_questions.js` tags/uploads question
/// documents -- that script keeps writing to `questions` exactly as before.
class PracticeAreaService {
  final _col = FirebaseFirestore.instance.collection('practiceAreas');

  /// Fetches every practice area document, sorted by `order` ascending.
  /// Uses a simple unfiltered `get()` (no Firestore `orderBy`) and sorts in
  /// memory -- consistent with this project's convention of avoiding
  /// composite-index dependencies for what is a very small collection.
  Future<List<PracticeAreaDoc>> getAll() async {
    final snap = await _col.get();
    final areas = snap.docs
        .map((d) => PracticeAreaDoc.fromDoc(d.id, d.data()))
        .toList();
    areas.sort((a, b) => a.order.compareTo(b.order));
    return areas;
  }

  /// Toggles (or explicitly sets) the `active` flag on a single practice
  /// area document. Used by the Admin panel's per-area switch.
  Future<void> setActive(String id, bool active) async {
    await _col.doc(id).set({'active': active}, SetOptions(merge: true));
  }

  /// Creates or fully overwrites a practice area document. Mainly useful
  /// for the one-time seeding script; the app itself only ever calls
  /// [setActive] from the Admin panel.
  Future<void> upsert(PracticeAreaDoc area) async {
    await _col.doc(area.id).set(area.toMap(), SetOptions(merge: true));
  }

  /// True if the practiceAreas collection already has at least one
  /// document (used to decide whether the local fallback list is needed).
  Future<bool> hasAnyAreas() async {
    final snap = await _col.limit(1).get();
    return snap.docs.isNotEmpty;
  }
}
