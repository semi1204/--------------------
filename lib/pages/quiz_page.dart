import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/providers/quiz_provider.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
import 'edit_quiz_page.dart';
import '../providers/theme_provider.dart';
import '../widgets/close_button.dart';

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
  final AutoScrollController _scrollController =
      AutoScrollController(); // Use AutoScrollController

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<QuizProvider>().loadQuizzesAndSetInitialScroll(
            widget.subjectId,
            widget.quizTypeId,
          );
      final initialIndex = context.read<QuizProvider>().lastScrollIndex;
      // Scroll to the initial index
      _scrollController.scrollToIndex(
        initialIndex,
        preferPosition: AutoScrollPosition.begin,
      );
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
                  controller: _scrollController, // Set the controller here
                  slivers: [
                    const SliverAppBar(
                      title: Text('Quiz'),
                      floating: true,
                      snap: true,
                      pinned: false,
                      actions: [
                        CustomCloseButton(),
                      ],
                    ),
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
                              onAnswerSelected: (answerIndex) => _selectAnswer(
                                  quizProvider, quiz.id, answerIndex),
                              onResetQuiz: () =>
                                  _resetQuiz(quizProvider, quiz.id),
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
    );
  }

  void _selectAnswer(
      QuizProvider quizProvider, String quizId, int answerIndex) {
    quizProvider.selectAnswer(
      widget.subjectId,
      widget.quizTypeId,
      quizId,
      answerIndex,
    );
  }

  void _resetQuiz(QuizProvider quizProvider, String quizId) {
    quizProvider.resetQuiz(widget.subjectId, widget.quizTypeId, quizId);
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
