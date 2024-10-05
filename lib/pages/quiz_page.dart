import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/models/quiz_type.dart';
import 'package:nursing_quiz_app_6/models/subject.dart';
import 'package:nursing_quiz_app_6/pages/subject_page.dart';
import 'package:nursing_quiz_app_6/providers/quiz_provider.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
import 'edit_quiz_page.dart';
import '../providers/theme_provider.dart';
import '../widgets/close_button.dart';
import '../widgets/linked_title.dart'; // Add this import
import '../utils/constants.dart'; // Add this import

class QuizPage extends StatefulWidget {
  final Subject subject;
  final QuizType quizType;

  const QuizPage({
    super.key,
    required this.subject,
    required this.quizType,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final AutoScrollController _scrollController = AutoScrollController();
  // subject와 quizType 변수 선언 제거

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final quizProvider = context.read<QuizProvider>();

      // 과목과 퀴즈 타입 ID 설정
      quizProvider.setSelectedSubjectId(widget.subject.id);
      quizProvider.setSelectedQuizTypeId(widget.quizType.id);

      // 퀴즈 로드 및 스크롤 설정
      await quizProvider.loadQuizzesAndSetInitialScroll(
        widget.subject.id,
        widget.quizType.id,
      );
      final initialIndex = quizProvider.lastScrollIndex;
      // Scroll to the initial index
      _scrollController.scrollToIndex(
        initialIndex,
        preferPosition: AutoScrollPosition.begin,
      );

      // 상태 업데이트를 위해 setState 호
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) {
          // Reset the sort option when leaving the page
          context.read<QuizProvider>().resetSortOption();
        }
        // No need to return anything
      },
      child: Consumer3<QuizProvider, UserProvider, ThemeProvider>(
        builder: (context, quizProvider, userProvider, themeProvider, child) {
          return Scaffold(
            body: quizProvider.quizzes.isEmpty
                ? Center(
                    child: Text(
                      quizProvider.isFilterEmpty
                          ? '선택한 필터에 해당하는 퀴즈가 없습니다.'
                          : '퀴즈를 불러오는 중입니다',
                      style: getAppTextStyle(context, fontSize: 16),
                    ),
                  )
                : CustomScrollView(
                    controller: _scrollController, // Set the controller here
                    slivers: [
                      SliverAppBar(
                        title: LinkedTitle(
                          //  selceted subject(이름) > selected quizType(이름)
                          // Done : subjectName, quizTypeName 변수 사용
                          titles: [widget.subject.name, widget.quizType.name],
                          onTap: (index) {
                            if (index == 0) {
                              // Navigate to SubjectPage
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const SubjectPage(),
                                ),
                              );
                            } else if (index == 1) {
                              // Navigate back to QuizTypePage
                              Navigator.of(context).pop();
                            }
                            // 페이지를 나갈 때 정렬 옵션을 리셋합니다.
                            quizProvider.resetSortOption();
                          },
                          textStyle: getAppTextStyle(context, fontSize: 16),
                        ),
                        floating: true,
                        snap: true,
                        pinned: false,
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.sort),
                            onPressed: () =>
                                _showFilterDialog(context, quizProvider),
                          ),
                          const CustomCloseButton(),
                        ],
                      ),
                      // Done : Quizpage의 AppBar title 의 오른쪽에 정렬 아이콘 추가 후 클릭하면 quizpage 내에서 빨간색, 노란색, 초록색 카드를 선별하는 popup 띄우기
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final quiz = quizProvider.quizzes[index];
                            final selectedAnswer =
                                quizProvider.selectedAnswers[quiz.id];
                            return AutoScrollTag(
                              key: ValueKey(index),
                              controller: _scrollController,
                              index: index,
                              child: QuizPageCard(
                                key: ValueKey(quiz.id),
                                quiz: quiz,
                                questionNumber: index + 1,
                                isAdmin: userProvider.isAdmin,
                                onEdit: () => _editQuiz(quiz),
                                onDelete: () => _deleteQuiz(quiz),
                                onAnswerSelected: (answerIndex) =>
                                    _selectAnswer(
                                        quizProvider, quiz.id, answerIndex),
                                onResetQuiz: () =>
                                    _resetQuiz(quizProvider, quiz.id),
                                subjectId: widget.subject.id,
                                quizTypeId: widget.quizType.id,
                                selectedOptionIndex: selectedAnswer,
                                isQuizPage: true,
                                nextReviewDate: userProvider
                                        .getNextReviewDate(
                                          widget.subject.id,
                                          widget.quizType.id,
                                          quiz.id,
                                        )
                                        ?.toIso8601String() ??
                                    DateTime.now().toIso8601String(),
                                rebuildExplanation:
                                    quizProvider.rebuildExplanation,
                              ),
                            );
                          },
                          childCount: quizProvider.quizzes.length,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  void _showFilterDialog(BuildContext context, QuizProvider quizProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('카드 필터'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<SortOption>(
                title: const Text('모든 카드'),
                value: SortOption.all,
                groupValue: quizProvider.currentSortOption,
                onChanged: (SortOption? value) {
                  quizProvider.setSortOption(value!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('빨간색 카드 (60% 미만)'),
                value: SortOption.low,
                groupValue: quizProvider.currentSortOption,
                onChanged: (SortOption? value) {
                  quizProvider.setSortOption(value!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('노란색 카드 (60% - 85%)'),
                value: SortOption.medium,
                groupValue: quizProvider.currentSortOption,
                onChanged: (SortOption? value) {
                  quizProvider.setSortOption(value!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<SortOption>(
                title: const Text('초록색 카드 (85% 이상)'),
                value: SortOption.high,
                groupValue: quizProvider.currentSortOption,
                onChanged: (SortOption? value) {
                  quizProvider.setSortOption(value!);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectAnswer(
      QuizProvider quizProvider, String quizId, int answerIndex) {
    quizProvider.selectAnswer(
      widget.subject.id,
      widget.quizType.id,
      quizId,
      answerIndex,
    );
    quizProvider.updateQuizAccuracy(
        widget.subject.id, widget.quizType.id, quizId);
  }

  void _resetQuiz(QuizProvider quizProvider, String quizId) {
    quizProvider.resetQuiz(widget.subject.id, widget.quizType.id, quizId);
    quizProvider.updateQuizAccuracy(
        widget.subject.id, widget.quizType.id, quizId);
  }

  void _editQuiz(Quiz quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditQuizPage(
          quiz: quiz,
          subjectId: widget.subject.id,
          quizTypeId: widget.quizType.id,
        ),
      ),
    );
  }

  void _deleteQuiz(Quiz quiz) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Quiz'),
          content: const Text('Are you sure you want to delete this quiz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                final quizProvider = context.read<QuizProvider>();
                await quizProvider.deleteQuiz(
                    widget.subject.id, widget.quizType.id, quiz.id);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
