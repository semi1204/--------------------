import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/markdown_widgets.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:provider/provider.dart';

class QuizExplanation extends StatelessWidget {
  final String explanation;
  final List<String> keywords;
  final Logger logger;
  final String quizId;
  final String subjectId;
  final String quizTypeId;

  const QuizExplanation({
    super.key,
    required this.explanation,
    required this.keywords,
    required this.logger,
    required this.quizId,
    required this.subjectId,
    required this.quizTypeId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (keywords.isNotEmpty) ...[
          const Text(
            'Keywords',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4.0,
            runSpacing: 2.0,
            children:
                keywords.map((keyword) => Chip(label: Text(keyword))).toList(),
          ),
          const SizedBox(height: 16),
        ],
        const Text(
          'Explanation',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        MarkdownRenderer(
          data: explanation,
          logger: logger,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('다시 복습할래요!'),
            onPressed: () => _markForReview(context),
          ),
        ),
      ],
    );
  }

  void _markForReview(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.markQuizForReview(subjectId, quizTypeId, quizId);
    logger.i('Quiz marked for review: $quizId');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('복습 목록에 추가되었습니다.')),
    );
  }
}
