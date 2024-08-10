import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/widgets/common_widgets.dart';
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
    final logger = Provider.of<Logger>(context, listen: false);
    final nextReviewDate =
        userProvider.getNextReviewDate(subjectId, quizTypeId, quizId);
    final isInReviewList =
        nextReviewDate != null && nextReviewDate.isAfter(DateTime.now());

    logger.d(
        'QuizExplanation build: quizId=$quizId, nextReviewDate=$nextReviewDate, isInReviewList=$isInReviewList');

    return Column(
      // --------- TODO : provider에서 복습목록 여부 판단 후 UI 재빌드 필요함. ---------//
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
          // TODO : 버튼이 유동적으로 바뀌지 않음. 수정필요.
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            icon: Icon(
              isInReviewList ? Icons.remove_circle : Icons.add_circle,
              color: isInReviewList ? Colors.red : Colors.green,
            ),
            label: Text(isInReviewList ? '복습 목록에서 제거' : '복습 목록에 추가'),
            onPressed: () => _toggleReviewStatus(
                context, userProvider, logger, isInReviewList),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isInReviewList ? Colors.red[100] : Colors.green[100],
            ),
          ),
        ),
      ],
    );
  }

  // --------- DONE : updateUserQuizData 호출로 변경 ---------//
  void _toggleReviewStatus(BuildContext context, UserProvider userProvider,
      Logger logger, bool markForReview) {
    logger.i('Toggling review status for quiz: $quizId');

    userProvider.updateUserQuizData(
      subjectId,
      quizTypeId,
      quizId,
      true, // isCorrect doesn't matter for review toggling
      toggleReviewStatus: !markForReview,
    );
    logger.d('퀴즈 복습 목록에서 제거됨: quizId=$quizId');

    // --------- TODO : getNextReviewTimeString의 시간 데이터 값 추적 확인필요 : 복습시간이 anki 알고리즘을 사용하고 있는지 확인 필요. //
    final reviewTimeString =
        userProvider.getNextReviewTimeString(subjectId, quizTypeId, quizId);

    logger.d('다음 복습 시간: $reviewTimeString');

    ScaffoldMessenger.of(context).showSnackBar(
      CommonSnackBar(
        message: markForReview
            ? '복습 목록에서 제거되었습니다.'
            : '복습 목록에 추가되었습니다!\n⏰ 다음 복습: $reviewTimeString 후',
      ),
    );
  }
}
