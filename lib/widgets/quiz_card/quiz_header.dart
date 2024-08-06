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
    super.key,
    required this.quiz,
    required this.subjectId,
    required this.quizTypeId,
    required this.onResetQuiz,
    required this.logger,
  });

  // 수정시 주의사항:
  // 문제의 가장 상단엔, keyword, accuracy, reset button이 Row로 표시되어야 합니다.
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 좌측: 기출문제 연도와 시험 유형
        Text(
          _getExamInfo(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        // 우측: 정답률과 초기화 버튼
        Row(
          children: [
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
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: onResetQuiz,
              tooltip: 'Reset Quiz',
            ),
          ],
        ),
      ],
    );
  }

  String _getExamInfo() {
    String examInfo = '';
    if (quiz.year != null) {
      examInfo += '${quiz.year} ';
    }
    if (quiz.examType != null && quiz.examType!.isNotEmpty) {
      examInfo += quiz.examType!;
    }
    return examInfo.isNotEmpty ? examInfo : '기출문제';
  }
}