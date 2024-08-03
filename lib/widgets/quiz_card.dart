// 수정 시 주의사항:
// quizcard 는 incorrectpage와, quizpage에서 사용되는 위젯입니다.
// quizcard는 각각의 페이지에서 동일하게 공유되지만,
// 몇 가지의 차이점이 존재합니다. incorrectpage의 카드 위젯에서는
// quizpage의 카드 위젯 => 사용자가 선택한 option은 항상 표시됩니다. 초기화 버튼을 통해서'만' 선택한 option을 초기화할 수 있습니다.
// incorrectpage의 카드 위젯에서는 사용자가 선택한 기존의 option을 표시하지 않습니다.
// 즉, incorrectpage의 quizcard의 radio 버튼은 항상 빈 option을 가져오면서,
// incorrectpage 화면 자체에서 그때 당시의 사용자의 선택한 option을 새롭게 표시하며 Snackbar를 띄웁니다.
// incorrectpage에서 사용자가 선택한 option은 오답인지, 정답인지만 반영해, 기기내부와 서버에서 저장되며,
// 복습시간에 반영이 됩니다.

import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/quiz_admin_actions.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/quiz_explanation.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/quiz_header.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/quiz_options.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/quiz_question.dart';
import 'package:provider/provider.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import 'package:logger/logger.dart';

// 각각의 데이터 구조는 삭제하면 안됩니다.
class QuizCard extends StatefulWidget {
  final Quiz quiz;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final int questionNumber;
  final int? selectedOptionIndex;
  final Function(int)? onAnswerSelected;
  final bool isIncorrectAnswersMode;
  final bool isScrollable;
  final VoidCallback? onResetQuiz;
  final VoidCallback? onDeleteReview;
  final String subjectId;
  final String quizTypeId;
  final bool isQuizPage; // QuizPage에서 사용되는지 여부

  const QuizCard({
    super.key, // super 키워드 사용
    required this.quiz,
    this.isAdmin = false,
    this.onEdit,
    this.onDelete,
    required this.questionNumber,
    this.selectedOptionIndex,
    this.onAnswerSelected,
    this.isIncorrectAnswersMode = false,
    this.isScrollable = false,
    this.onResetQuiz,
    this.onDeleteReview,
    required this.subjectId,
    required this.quizTypeId,
    this.isQuizPage = false,
  });

  @override
  State<QuizCard> createState() => _QuizCardState();
}

// 수정시 주의사항:
//quizCard의 모든 로그는 무조건 저장되어있어야 함.
//사용자 선택 UI부터 정답률 User의 기록까지, 뒤로갔다가 다시 와도,
//기기를 껐다가 켜도, 로그인과 로그아웃을 해도

class _QuizCardState extends State<QuizCard> {
  late final Logger _logger;
  late final UserProvider _userProvider;
  DateTime? _startTime;
  int? _selectedOptionIndex;
  bool _hasAnswered = false;
  int _mistakeCount = 0;

  @override
  void initState() {
    super.initState();
    _logger = Provider.of<Logger>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger.i('QuizCard initialized for quiz: ${widget.quiz.question}');
    _startTime = DateTime.now();
    _loadUserAnswer();
    _loadMistakeCount();
  }

  // 사용자의 실수 횟수 로드 메소드
  void _loadMistakeCount() {
    _mistakeCount = _userProvider.getQuizMistakeCount(
        widget.subjectId, widget.quizTypeId, widget.quiz.id);
    _logger.i('Loaded mistake count: $_mistakeCount');
  }

  // 사용자의 답변 로드 메소드
  void _loadUserAnswer() {
    _selectedOptionIndex = _userProvider.getUserAnswer(
        widget.subjectId, widget.quizTypeId, widget.quiz.id);
    _hasAnswered = _selectedOptionIndex != null;
    _logger.i('Loaded user answer: $_selectedOptionIndex');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            QuizHeader(
              quiz: widget.quiz,
              subjectId: widget.subjectId,
              quizTypeId: widget.quizTypeId,
              onResetQuiz: _resetQuiz,
              logger: _logger,
            ),
            const SizedBox(height: 16),
            QuizQuestion(
              question: widget.quiz.question,
              logger: _logger,
            ),
            const SizedBox(height: 16),
            QuizOptions(
              quiz: widget.quiz,
              selectedOptionIndex: _selectedOptionIndex,
              hasAnswered: _hasAnswered,
              isQuizPage: widget.isQuizPage,
              isIncorrectAnswersMode: widget.isIncorrectAnswersMode,
              onSelectOption: _selectOption,
              logger: _logger,
            ),
            if (_hasAnswered || widget.isIncorrectAnswersMode) ...[
              const SizedBox(height: 16),
              QuizExplanation(
                explanation: widget.quiz.explanation,
                logger: _logger,
              ),
            ],
            if (widget.isAdmin)
              QuizAdminActions(
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
              ),
          ],
        ),
      ),
    );
  }

  void _resetQuiz() {
    setState(() {
      _selectedOptionIndex = null;
      _hasAnswered = false;
      _startTime = DateTime.now();
      _mistakeCount = 0;
    });
    _userProvider.resetUserAnswers(widget.subjectId, widget.quizTypeId,
        quizId: widget.quiz.id);
    _logger.i('Quiz reset for: ${widget.quiz.id}');
  }

  void _selectOption(int index) {
    _logger.i('Selecting option $index for quiz ${widget.quiz.id}');
    setState(() {
      _selectedOptionIndex = index;
      _hasAnswered = true;
    });

    final endTime = DateTime.now();
    final answerTime = endTime.difference(_startTime!);
    final isCorrect = index == widget.quiz.correctOptionIndex;

    if (!isCorrect) {
      setState(() {
        _mistakeCount++;
      });
    }

    _userProvider.updateUserQuizData(
      widget.subjectId,
      widget.quizTypeId,
      widget.quiz.id,
      isCorrect,
      answerTime: answerTime,
      selectedOptionIndex: index,
      mistakeCount: _mistakeCount,
    );

    widget.onAnswerSelected?.call(index);

    _showAnswerSnackBar(isCorrect);

    _logger.i(
        'User selected option $index. Correct: $isCorrect. Mistake count: $_mistakeCount');
  }

  void _showAnswerSnackBar(bool isCorrect) {
    // 수정: getNextReviewTimeString 메서드 호출 수정
    final reviewTimeString = _userProvider.getNextReviewTimeString(
      widget.subjectId,
      widget.quizTypeId,
      widget.quiz.id,
    );

    _logger.i(
        'Showing answer snackbar. IsCorrect: $isCorrect, Next review: $reviewTimeString');

    final snackBar = SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? '정답입니다! 🎉' : '오답입니다. 다시 도전해보세요! 💪',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '다음 복습은 $reviewTimeString 후입니다.',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
        ],
      ),
      backgroundColor: isCorrect
          ? const Color.fromARGB(255, 144, 223, 146)
          : const Color.fromARGB(255, 218, 141, 135),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
