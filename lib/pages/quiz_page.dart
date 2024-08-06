import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _quizService = Provider.of<QuizService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger = Provider.of<Logger>(context, listen: false);
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    _logger.i(
        'Loading quizzes for subject: ${widget.subjectId}, quizType: ${widget.quizTypeId}');
    try {
      // 수정: await 사용
      final quizzes =
          await _quizService.getQuizzes(widget.subjectId, widget.quizTypeId);
      if (mounted) {
        // 추가: mounted 체크
        setState(() {
          _quizzes = quizzes;
        });
      }
      _logger.i('Loaded ${_quizzes.length} quizzes');
    } catch (e) {
      _logger.e('Error loading quizzes: $e');
    }
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
              : ListView.builder(
                  itemCount: _quizzes.length,
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
                      onAnswerSelected: (answerIndex) {
                        _logger.i(
                            'Answer selected for quiz: ${quiz.id}, answer: $answerIndex');
                        userProvider.saveUserAnswer(
                          widget.subjectId,
                          widget.quizTypeId,
                          quiz.id,
                          answerIndex,
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
