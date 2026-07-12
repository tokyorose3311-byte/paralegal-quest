enum QuestionType { mountain, cave }

QuestionType _typeFromString(String? s) =>
    s == 'cave' ? QuestionType.cave : QuestionType.mountain;

String _typeToString(QuestionType t) =>
    t == QuestionType.cave ? 'cave' : 'mountain';

class QuizQuestion {
  /// Firestore document id. Null for the built-in local fallback questions
  /// that haven't been migrated/synced yet.
  final String? id;
  final String category;
  final QuestionType type;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    this.id,
    required this.category,
    required this.type,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  QuizQuestion copyWith({
    String? id,
    String? category,
    QuestionType? type,
    String? question,
    List<String>? options,
    int? correctIndex,
    String? explanation,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      category: category ?? this.category,
      type: type ?? this.type,
      question: question ?? this.question,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      explanation: explanation ?? this.explanation,
    );
  }

  /// Builds a QuizQuestion from a Firestore document.
  factory QuizQuestion.fromDoc(String id, Map<String, dynamic> d) {
    final rawOptions = d['options'];
    final options = rawOptions is List
        ? rawOptions.map((e) => e.toString()).toList()
        : <String>[];
    return QuizQuestion(
      id: id,
      category: (d['category'] as String?) ?? 'General',
      type: _typeFromString(d['type'] as String?),
      question: (d['question'] as String?) ?? '',
      options: options,
      correctIndex: (d['correctIndex'] as num?)?.toInt() ?? 0,
      explanation: (d['explanation'] as String?) ?? '',
    );
  }

  /// Converts to a Firestore-friendly map (no id -- that's the doc key).
  Map<String, dynamic> toMap() => {
    'category': category,
    'type': _typeToString(type),
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
  };
}
