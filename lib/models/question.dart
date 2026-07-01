enum QuestionType { mountain, cave }

class QuizQuestion {
  final String category;
  final QuestionType type;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.category,
    required this.type,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}
