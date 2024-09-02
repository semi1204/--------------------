import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/providers/quiz_provider.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
import 'edit_quiz_page.dart';
import 'dart:async'; // Timer를 사용하기 위해 추가
import '../widgets/close_button.dart'; // 커스텀 CloseButton import
import '../providers/theme_provider.dart';

class QuizPage extends StatefulWidget {
  final String subjectId;
  final String quizTypeId;

  const QuizPage({
    super.key,
    required this.subjectId,
    required this.quizTypeId,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _positionsListener.itemPositions.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<QuizProvider>()
          .loadQuizzesAndSetInitialScroll(widget.subjectId, widget.quizTypeId);
    });
  }

  @override
  void dispose() {
    _positionsListener.itemPositions.removeListener(_onScroll);
    _scrollTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(milliseconds: 100), () {
      if (_positionsListener.itemPositions.value.isNotEmpty) {
        final firstVisibleItemIndex =
            _positionsListener.itemPositions.value.first.index;
        final quizProvider = context.read<QuizProvider>();
        if (firstVisibleItemIndex != quizProvider.lastScrollIndex) {
          final isScrollingUp =
              firstVisibleItemIndex < quizProvider.lastScrollIndex;
          quizProvider.setAppBarVisibility(isScrollingUp);
          quizProvider.setLastScrollIndex(firstVisibleItemIndex);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<QuizProvider, UserProvider, ThemeProvider>(
      builder: (context, quizProvider, userProvider, themeProvider, child) {
        return Scaffold(
          body: quizProvider.quizzes.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    // TODO : 앱바 삭제 필요
                    SliverAppBar(
                      floating: true,
                      snap: true,
                      pinned: false,
                      title: const Text('문제', style: TextStyle(fontSize: 18)),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      actions: const [CustomCloseButton()],
                      toolbarHeight: kToolbarHeight / 1.4,
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height,
                        child: ScrollablePositionedList.builder(
                          itemCount: quizProvider.quizzes.length,
                          itemScrollController: quizProvider.scrollController,
                          itemPositionsListener: _positionsListener,
                          itemBuilder: (context, index) {
                            final quiz = quizProvider.quizzes[index];
                            final selectedAnswer =
                                quizProvider.selectedAnswers[quiz.id];
                            return QuizPageCard(
                              key: ValueKey(quiz.id),
                              quiz: quiz,
                              questionNumber: index + 1,
                              isAdmin: userProvider.isAdmin,
                              onEdit: () => _editQuiz(quiz),
                              onDelete: () => _deleteQuiz(quiz),
                              onAnswerSelected: (answerIndex) {
                                quizProvider.selectAnswer(
                                  widget.subjectId,
                                  widget.quizTypeId,
                                  quiz.id,
                                  answerIndex,
                                  index,
                                );
                              },
                              onResetQuiz: () {
                                quizProvider.resetQuiz(widget.subjectId,
                                    widget.quizTypeId, quiz.id);
                              },
                              subjectId: widget.subjectId,
                              quizTypeId: widget.quizTypeId,
                              selectedOptionIndex: selectedAnswer,
                              isQuizPage: true,
                              nextReviewDate: userProvider
                                      .getNextReviewDate(
                                        widget.subjectId,
                                        widget.quizTypeId,
                                        quiz.id,
                                      )
                                      ?.toIso8601String() ??
                                  DateTime.now().toIso8601String(),
                              rebuildExplanation:
                                  quizProvider.rebuildExplanation,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  void _editQuiz(Quiz quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditQuizPage(
          quiz: quiz,
          subjectId: widget.subjectId,
          quizTypeId: widget.quizTypeId,
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
                    widget.subjectId, widget.quizTypeId, quiz.id);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
