import 'package:flutter/material.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';

/// Shows the question modal and resolves with the chosen answer index,
/// after the user has seen feedback and pressed the "Advance/Hold" button.
Future<int?> showQuestionDialog({
  required BuildContext context,
  required QuizQuestion question,
  required int roll,
  required GameColors colors,
}) {
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xE6060C18),
    builder: (context) =>
        _QuestionDialogContent(question: question, roll: roll, colors: colors),
  );
}

class _QuestionDialogContent extends StatefulWidget {
  final QuizQuestion question;
  final int roll;
  final GameColors colors;

  const _QuestionDialogContent({
    required this.question,
    required this.roll,
    required this.colors,
  });

  @override
  State<_QuestionDialogContent> createState() => _QuestionDialogContentState();
}

class _QuestionDialogContentState extends State<_QuestionDialogContent> {
  int? _chosen;
  bool _answered = false;

  static const _letters = ['A', 'B', 'C', 'D'];

  void _choose(int i) {
    if (_answered) return;
    setState(() {
      _chosen = i;
      _answered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final q = widget.question;
    final isMtn = q.type == QuestionType.mountain;
    final correct = _chosen == q.correctIndex;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1C3157), Color(0xFF0D1A31)],
            ),
            border: Border.all(color: colors.accent, width: 2),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 40,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.accent2,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isMtn ? '⛰️ MOUNTAIN QUESTION' : '🕳️ CAVE QUESTION',
                  style: AppText.cinzel(
                    fontSize: 10.5,
                    color: Colors.white,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${q.category} • worth ${widget.roll} ${widget.roll == 1 ? "step" : "steps"}',
                style: AppText.spectral(
                  fontSize: 12,
                  color: colors.cream.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                q.question,
                style: AppText.spectral(
                  fontSize: 17,
                  color: colors.cream,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(q.options.length, (i) {
                Color bg = Colors.white.withValues(alpha: 0.05);
                Color border = colors.accent.withValues(alpha: 0.3);
                if (_answered) {
                  if (i == q.correctIndex) {
                    bg = colors.good.withValues(alpha: 0.3);
                    border = colors.good;
                  } else if (i == _chosen) {
                    bg = colors.bad.withValues(alpha: 0.3);
                    border = colors.bad;
                  }
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _choose(i),
                    borderRadius: BorderRadius.circular(9),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        border: Border.all(color: border, width: 1.5),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${_letters[i]}  ',
                            style: AppText.cinzel(
                              fontSize: 14,
                              color: colors.brass,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              q.options[i],
                              style: AppText.spectral(
                                fontSize: 15,
                                color: colors.cream,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (_answered) ...[
                const SizedBox(height: 8),
                Text(
                  (correct ? 'Correct. ' : 'Not quite. ') + q.explanation,
                  style: AppText.spectral(
                    fontSize: 14.5,
                    fontStyle: FontStyle.italic,
                    color: correct
                        ? const Color(0xFF9FE0B0)
                        : const Color(0xFFF0A8A6),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_chosen),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brassBright,
                      foregroundColor: const Color(0xFF1A140C),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      correct ? 'Advance ${widget.roll}' : 'Hold position',
                      style: AppText.cinzel(
                        fontSize: 14,
                        color: const Color(0xFF1A140C),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
