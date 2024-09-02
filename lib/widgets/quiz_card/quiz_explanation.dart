import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/utils/constants.dart';
import 'package:nursing_quiz_app_6/widgets/common_widgets.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/markdown_widgets.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class QuizExplanation extends StatefulWidget {
  final String explanation;
  final List<String> keywords;
  final Logger logger;
  final String quizId;
  final String subjectId;
  final String quizTypeId;
  final bool rebuildTrigger;
  final Widget? feedbackButtons; // New property added

  const QuizExplanation({
    super.key,
    required this.explanation,
    required this.keywords,
    required this.logger,
    required this.quizId,
    required this.subjectId,
    required this.quizTypeId,
    required this.rebuildTrigger,
    this.feedbackButtons, // Added to the constructor
  });

  @override
  _QuizExplanationState createState() => _QuizExplanationState();
}

class _QuizExplanationState extends State<QuizExplanation> {
  late bool isInReviewList;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    isInReviewList = userProvider.isInReviewList(
      widget.subjectId,
      widget.quizTypeId,
      widget.quizId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final textColor =
            themeProvider.isDarkMode ? Colors.white : Colors.black;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.keywords.isNotEmpty) ...[
              const Text(
                '키워드',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4.0,
                runSpacing: 2.0,
                children: widget.keywords
                    .map((keyword) => Chip(label: Text(keyword)))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              '해설',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            MarkdownRenderer(
              data: widget.explanation,
              logger: widget.logger,
            ),
            const SizedBox(height: 16),
            if (widget.feedbackButtons != null) ...[
              widget.feedbackButtons!,
              const SizedBox(height: 16),
            ],
            Align(
              // 버튼을 누르면, 복습카드로 전환함
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: Icon(
                  isInReviewList ? Icons.remove_circle : Icons.add_circle,
                  color: isInReviewList ? Colors.red : Colors.green,
                ),
                label: Text(
                  isInReviewList ? '복습 목록에서 제거' : '복습 목록에 추가',
                  style: TextStyle(color: textColor),
                ),
                onPressed: () =>
                    _toggleReviewStatus(context, userProvider, widget.logger),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isInReviewList
                      ? INCORRECT_OPTION_COLOR
                      : CORRECT_OPTION_COLOR,
                  foregroundColor: textColor,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 복습상태를 토글하는 메소드
  void _toggleReviewStatus(
      BuildContext context, UserProvider userProvider, Logger logger) async {
    logger.i('Toggling review status for quiz: ${widget.quizId}');

    String message;
    String? reviewTimeString;

    if (isInReviewList) {
      // 복습목록에서 제거
      await userProvider.removeFromReviewList(
        widget.subjectId,
        widget.quizTypeId,
        widget.quizId,
      );
      logger.d('퀴즈가 복습 목록에서 제거됨: quizId=${widget.quizId}');
      message = '복습 목록에서 제거되었습니다.';
    } else {
      // 복습목록에 추가
      await userProvider.addToReviewList(
        widget.subjectId,
        widget.quizTypeId,
        widget.quizId,
      );
      logger.d('퀴즈가 복습 목록에 추가됨: quizId=${widget.quizId}');
      // 복습목록에 추가하는 순간 다음 복습 시간을 가져옴
      reviewTimeString = userProvider.formatNextReviewDate(
        widget.subjectId,
        widget.quizTypeId,
        widget.quizId,
      );
      message = '복습 목록에 추가되었습니다!\n⏰ 다음 복습: $reviewTimeString 후';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      CommonSnackBar(message: message),
    );

    setState(() {
      isInReviewList = !isInReviewList;
    });
  }
}
