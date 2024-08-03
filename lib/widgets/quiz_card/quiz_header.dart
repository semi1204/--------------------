import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/models/quiz.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/accuracy_display.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class QuizHeader extends StatelessWidget {
  final Quiz quiz;
  final String subjectId;
  final String quizTypeId;
  final VoidCallback onResetQuiz;
  final Logger logger;

  const QuizHeader({
    Key? key,
    required this.quiz,
    required this.subjectId,
    required this.quizTypeId,
    required this.onResetQuiz,
    required this.logger,
  }) : super(key: key);
  // 수정시 주의사항:
  // 문제의 가장 상단엔, keyword, accuracy, reset button이 Row로 표시되어야 합니다.
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildKeywords()),
        Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final accuracy = userProvider.getQuizAccuracy(
              subjectId,
              quizTypeId,
              quiz.id,
            );
            logger.d('Quiz accuracy: $accuracy');
            return AccuracyDisplay(accuracy: accuracy);
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: onResetQuiz,
          tooltip: 'Reset Quiz',
        ),
      ],
    );
  }

  Widget _buildKeywords() {
    return Wrap(
      spacing: 4.0,
      runSpacing: 2.0,
      children:
          quiz.keywords.map((keyword) => Chip(label: Text(keyword))).toList(),
    );
  }
}
