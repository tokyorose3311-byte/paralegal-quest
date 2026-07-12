import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question.dart';

/// Cloud-backed question bank. Every device / app install reads the SAME
/// Firestore collection, so a question added or edited once (via the Admin
/// panel) is available everywhere immediately without needing an app
/// update or Play Store resubmission.
class QuestionService {
  final _col = FirebaseFirestore.instance.collection('questions');

  /// Fetches every question in the bank (for gameplay + admin panel).
  /// Uses a simple query (no orderBy) to avoid needing a composite index --
  /// see project conventions on avoiding Firestore index dependencies.
  Future<List<QuizQuestion>> getAll() async {
    final snap = await _col.get();
    return snap.docs
        .map((d) => QuizQuestion.fromDoc(d.id, d.data()))
        .toList();
  }

  /// Adds a brand new question. Firestore auto-generates the document id.
  Future<void> add(QuizQuestion q) async {
    await _col.add(q.toMap());
  }

  /// Updates an existing question (id must be set).
  Future<void> update(QuizQuestion q) async {
    if (q.id == null) {
      throw ArgumentError('Cannot update a question with no id.');
    }
    await _col.doc(q.id).set(q.toMap(), SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  /// One-time migration helper: uploads a batch of local questions into
  /// Firestore. Safe to call multiple times -- it always adds new docs
  /// (Firestore auto-ids), so only run this once per set of questions to
  /// avoid duplicates. Returns the number of questions written.
  Future<int> migrateFromLocal(List<QuizQuestion> local) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final q in local) {
      final ref = _col.doc();
      batch.set(ref, q.toMap());
    }
    await batch.commit();
    return local.length;
  }

  /// True if the questions collection already has at least one document
  /// (used to avoid accidentally re-running the migration and creating
  /// duplicates).
  Future<bool> hasAnyQuestions() async {
    final snap = await _col.limit(1).get();
    return snap.docs.isNotEmpty;
  }
}
