import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/providers/quiz_provider.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
import 'edit_quiz_page.dart';
import 'dart:async';
import '../providers/theme_provider.dart';

// TODO : AppBar 아래로 스크롤 내리면 AppBar 사라지게 하기
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
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();
  double _lastScrollOffset = 0;
  bool _isScrollingDown = false;
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _positionsListener.itemPositions.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizProvider>().loadQuizzesAndSetInitialScroll(
            widget.subjectId,
            widget.quizTypeId,
          );
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
        final firstVisibleItemPosition =
            _positionsListener.itemPositions.value.first;
        final currentScrollOffset = firstVisibleItemPosition.itemLeadingEdge;

        if (currentScrollOffset != _lastScrollOffset) {
          final isScrollingDown = currentScrollOffset < _lastScrollOffset;
          if (isScrollingDown != _isScrollingDown) {
            setState(() {
              _isScrollingDown = isScrollingDown;
              context
                  .read<QuizProvider>()
                  .setAppBarVisibility(!_isScrollingDown);
            });
          }
          _lastScrollOffset = currentScrollOffset;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<QuizProvider, UserProvider, ThemeProvider>(
      builder: (context, quizProvider, userProvider, themeProvider, child) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: quizProvider.isAppBarVisible ? kToolbarHeight : 0,
              child: AppBar(
                title: const Text('Quiz'),
              ),
            ),
          ),
          body: quizProvider.quizzes.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ScrollablePositionedList.builder(
                  itemCount: quizProvider.quizzes.length,
                  itemScrollController: _scrollController,
                  itemPositionsListener: _positionsListener,
                  initialScrollIndex: quizProvider.lastScrollIndex,
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
                        );
                      },
                      onResetQuiz: () {
                        quizProvider.resetQuiz(
                            widget.subjectId, widget.quizTypeId, quiz.id);
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
                      rebuildExplanation: quizProvider.rebuildExplanation,
                    );
                  },
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
