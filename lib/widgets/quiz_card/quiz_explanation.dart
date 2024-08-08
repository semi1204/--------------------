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
  final bool rebuildTrigger;

  const QuizExplanation({
    super.key,
    required this.explanation,
    required this.keywords,
    required this.logger,
    required this.quizId,
    required this.subjectId,
    required this.quizTypeId,
    required this.rebuildTrigger,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final nextReviewDate =
        userProvider.getNextReviewDate(subjectId, quizTypeId, quizId);
    final isInReviewList =
        nextReviewDate != null && nextReviewDate.isAfter(DateTime.now());

    logger.d(
        'QuizExplanation build: quizId=$quizId, isInReviewList=$isInReviewList, nextReviewDate=$nextReviewDate');

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
            icon: Icon(
              isInReviewList ? Icons.check_circle : Icons.refresh,
              color: isInReviewList ? Colors.green : null,
            ), // 복습목록에 있다면 체크 아이콘, 아니면 새로고침 아이콘
            label: Text(isInReviewList ? '복습 목록에 있음' : '다시 복습할래요!'),
            onPressed: isInReviewList ? null : () => _markForReview(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: isInReviewList ? Colors.grey[300] : null,
            ),
          ),
        ),
      ],
    );
  }

  void _markForReview(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    logger.d(
        'Marking quiz for review: quizId=$quizId, subjectId=$subjectId, quizTypeId=$quizTypeId');

    // 기존의 updateUserQuizData 메서드를 사용하여 복습 목록에 추가
    userProvider.updateUserQuizData(
      subjectId,
      quizTypeId,
      quizId,
      false, // isCorrect를 false로 설정하여 복습이 필요함을 나타냄
      isUnderstandingImproved: false, // 이해도버튼이 나타나지 않음
    );

    logger.d('Quiz marked for review: quizId=$quizId');

    final reviewTimeString = userProvider.getNextReviewTimeString(
      subjectId,
      quizTypeId,
      quizId,
    );

    logger.d('Next review time: $reviewTimeString');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '복습 목록에 추가되었습니다!\n⏰ 다음 복습: $reviewTimeString 후',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 106, 105, 106),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
