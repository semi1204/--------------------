import 'package:any_animated_button/any_animated_button.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/models/keyword.dart';
import 'package:nursing_quiz_app_6/widgets/common_widgets.dart';
import 'package:nursing_quiz_app_6/providers/user_provider.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/markdown_widgets.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/review_toggle_bloc.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class QuizExplanation extends StatefulWidget {
  final String explanation;
  final List<Keyword> keywords;
  final Logger logger;
  final String quizId;
  final String subjectId;
  final String quizTypeId;
  final bool rebuildTrigger;
  final Widget? feedbackButtons;
  final bool isReviewPage;
  final Function(String)? onRemoveCard;

  const QuizExplanation({
    super.key,
    required this.explanation,
    required this.keywords,
    required this.logger,
    required this.quizId,
    required this.subjectId,
    required this.quizTypeId,
    required this.rebuildTrigger,
    this.feedbackButtons,
    this.isReviewPage = false,
    this.onRemoveCard,
  });

  @override
  State createState() => _QuizExplanationState();
}

class _QuizExplanationState extends State<QuizExplanation> {
  late bool isInReviewList;
  late ReviewToggleBloc _reviewToggleBloc;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    isInReviewList = userProvider.isInReviewList(
      widget.subjectId,
      widget.quizTypeId,
      widget.quizId,
    );
    _reviewToggleBloc = ReviewToggleBloc();
  }

  @override
  void dispose() {
    _reviewToggleBloc.close();
    super.dispose();
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '해설',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                ReviewToggleButton(
                  bloc: _reviewToggleBloc,
                  isInReviewList: isInReviewList,
                  textColor: textColor,
                  onTap: () =>
                      _toggleReviewStatus(context, userProvider, widget.logger),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MarkdownRenderer(
              data: widget.explanation,
              logger: widget.logger,
            ),
            if (widget.keywords.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '키워드',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4.0,
                runSpacing: 2.0,
                children: widget.keywords
                    .map((keyword) => Chip(
                          label: Text(keyword.content),
                          onDeleted: () =>
                              _showKeywordDescription(context, keyword),
                        ))
                    .toList(),
              ),
            ],
            if (widget.feedbackButtons != null) ...[
              const SizedBox(height: 16),
              widget.feedbackButtons!,
            ],
          ],
        );
      },
    );
  }

  void _showKeywordDescription(BuildContext context, Keyword keyword) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.75,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      keyword.content,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    MarkdownRenderer(
                      data: keyword.description ?? '설명이 없습니다.',
                      logger: widget.logger,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleReviewStatus(
      BuildContext context, UserProvider userProvider, Logger logger) async {
    logger.i('Toggling review status for quiz: ${widget.quizId}');

    _reviewToggleBloc.add(TriggerAnyAnimatedButtonEvent(isInReviewList));

    String message;

    if (isInReviewList) {
      // 복습목록에서 제거
      await userProvider.removeFromReviewList(
        widget.subjectId,
        widget.quizTypeId,
        widget.quizId,
      );
      logger.d('퀴즈가 복습 목록에서 제거됨: quizId=${widget.quizId}');
      message = '복습 목록에서 제거되었습니다.';

      // Immediately remove the card from the review page
      if (widget.isReviewPage && widget.onRemoveCard != null) {
        widget.onRemoveCard!(widget.quizId);
        return; // return => 복습카드라면, reviewPage에서 곧바로 카드를 제거함
      }
    } else {
      // 복습목록에 추가
      await userProvider.addToReviewList(
        widget.subjectId,
        widget.quizTypeId,
        widget.quizId,
      );
      logger.d('퀴즈가 복습 목록에 추가됨: quizId=${widget.quizId}');
      String? reviewTimeString = userProvider.formatNextReviewDate(
        widget.subjectId,
        widget.quizTypeId,
        widget.quizId,
      )['understood'];
      message = '복습 목록에 추가되었습니다!\n⏰ 다음 복습: $reviewTimeString ';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      CommonSnackBar(message: message),
    );

    setState(() {
      isInReviewList = !isInReviewList;
    });
  }
}
