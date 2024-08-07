import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import 'package:logger/logger.dart';
import '../widgets/quiz_card.dart';
import 'edit_quiz_page.dart';

class QuizPage extends StatefulWidget {
  final String subjectId;
  final String quizTypeId;

  const QuizPage({
    super.key,
    required this.subjectId,
    required this.quizTypeId,
  }); // super.key 사용

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late final QuizService _quizService;
  late final UserProvider _userProvider;
  late final Logger _logger;
  List<Quiz> _quizzes = []; // admin만 접근이 가능한, 원래의 퀴즈 목록
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();
  int _initialScrollIndex = 0;

  @override
  void initState() {
    super.initState();
    _quizService = Provider.of<QuizService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger = Provider.of<Logger>(context, listen: false);
    _loadQuizzesAndSetInitialScroll();
  }

  Future<void> _loadQuizzesAndSetInitialScroll() async {
    _logger.i('Loading quizzes and setting initial scroll position');
    try {
      final quizzes =
          await _quizService.getQuizzes(widget.subjectId, widget.quizTypeId);
      if (mounted) {
        // 추가: mounted 체크
        setState(() {
          _quizzes = quizzes;
          _initialScrollIndex = _findLastAnsweredQuizIndex();
        });
        // 스크롤 위치 설정
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_initialScrollIndex > 0 && _scrollController.isAttached) {
            _scrollController.scrollTo(
              index: _initialScrollIndex,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        });
      }
      _logger.i(
          'Loaded ${_quizzes.length} quizzes, initial scroll index: $_initialScrollIndex');
    } catch (e) {
      _logger.e('Error loading quizzes: $e');
    }
  }

  int _findLastAnsweredQuizIndex() {
    for (int i = _quizzes.length - 1; i >= 0; i--) {
      if (_userProvider.getUserAnswer(
              widget.subjectId, widget.quizTypeId, _quizzes[i].id) !=
          null) {
        return i + 1; // 마지막으로 답변한 퀴즈의 다음 인덱스 반환
      }
    }
    return 0; // 모든 퀴즈가 미답변 상태일 경우
  }

  Future<void> _resetQuiz(String quizId) async {
    _logger.i('Resetting quiz: $quizId');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Quiz'),
          content: const Text(
              'Are you sure you want to reset this quiz? This will clear your answer and reset the accuracy.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Reset'),
              onPressed: () async {
                // quizId를 named parameter로 전달
                await _userProvider.resetUserAnswers(
                    widget.subjectId, widget.quizTypeId,
                    quizId: quizId);
                if (mounted) {
                  // mounted 체크 추가
                  setState(() {});
                  Navigator.of(context).pop();
                }
                _logger.i('Quiz reset completed');
              },
            ),
          ],
        );
      },
    );
  }

// 수정 시 주의 사항
// 1. QuizCard 위젯에서 User의 기존 선택지는 항상 표시되어있어야함.
// 2. User는 초기화 버튼으로만 선택지를 초기화할 수 있어야함.
// 3. User가 선택지를 변경하면, QuizCard 위젯은 즉시 변경된 선택지를 표시해야함.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: const [
          CloseButton(),
        ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          _logger.i('Rebuilding QuizPage');
          return _quizzes.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ScrollablePositionedList.builder(
                  itemCount: _quizzes.length,
                  itemScrollController: _scrollController,
                  itemPositionsListener: _positionsListener,
                  itemBuilder: (context, index) {
                    final quiz = _quizzes[index];
                    final selectedAnswer = userProvider.getUserAnswer(
                      widget.subjectId,
                      widget.quizTypeId,
                      quiz.id,
                    );
                    _logger.i(
                        'Quiz ${quiz.id} - Selected answer: $selectedAnswer');
                    return QuizCard(
                      key: ValueKey(quiz.id),
                      quiz: quiz,
                      questionNumber: index + 1,
                      isAdmin: userProvider.isAdmin,
                      onEdit: () => _editQuiz(quiz),
                      onDelete: () => _deleteQuiz(quiz),
                      // 선택된 답은 updateUserQuizData 에 저장됨
                      onAnswerSelected: (answerIndex) {
                        _logger.i(
                            'Answer selected for quiz: ${quiz.id}, answer: $answerIndex');
                        userProvider.updateUserQuizData(
                          widget.subjectId,
                          widget.quizTypeId,
                          quiz.id,
                          answerIndex == quiz.correctOptionIndex,
                          selectedOptionIndex: answerIndex,
                        );
                      },
                      onResetQuiz: () => _resetQuiz(quiz.id),
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
                          .toIso8601String(),
                    );
                  },
                );
        },
      ),
    );
  }

  void _editQuiz(Quiz quiz) {
    _logger.i('Editing quiz: ${quiz.id}');
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
    _logger.i('Deleting quiz: ${quiz.id}');
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
                await _quizService.deleteQuiz(
                    widget.subjectId, widget.quizTypeId, quiz.id);
                setState(() {
                  _quizzes.removeWhere((q) => q.id == quiz.id);
                });
                Navigator.of(context).pop();
                _logger.i('Quiz deleted: ${quiz.id}');
              },
            ),
          ],
        );
      },
    );
  }
}
