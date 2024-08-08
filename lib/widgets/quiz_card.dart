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
  final bool isScrollable;
  final VoidCallback? onResetQuiz;
  final VoidCallback? onDeleteReview;
  final String subjectId;
  final String quizTypeId;
  final bool isQuizPage; // QuizPage에서 사용되는지 여부
  final String nextReviewDate; // 이 줄을 추가합니다.

  const QuizCard({
    super.key, // super 키워드 사용
    required this.quiz,
    this.isAdmin = false,
    this.onEdit,
    this.onDelete,
    required this.questionNumber,
    this.selectedOptionIndex,
    this.onAnswerSelected,
    this.isScrollable = false,
    this.onResetQuiz,
    this.onDeleteReview,
    required this.subjectId,
    required this.quizTypeId,
    this.isQuizPage = false,
    required this.nextReviewDate, // 이 줄을 추가합니다.
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

  @override
  void initState() {
    super.initState();
    _logger = Provider.of<Logger>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _startTime = DateTime.now();
    _loadUserAnswer();
  }

  void _loadUserAnswer() {
    // 사용자가 선택한 답변을 가져와 _selectedOptionIndex에 저장
    _selectedOptionIndex = widget.selectedOptionIndex;
    _hasAnswered = _selectedOptionIndex != null;
  }

  @override
  // 사용자의 답변이 변경되었을 때, 로그를 출력하고 사용자의 답변을 가져옴
  void didUpdateWidget(QuizCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOptionIndex != oldWidget.selectedOptionIndex) {
      _logger.i(
          'QuizCard updated: selectedOptionIndex changed to ${widget.selectedOptionIndex}');
      _loadUserAnswer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
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
                  onSelectOption: (index) {
                    // updateUserProvider에 값이 저장됨
                    _selectOption(index, userProvider);
                  },
                  logger: _logger,
                ),
                if (_hasAnswered) ...[
                  const SizedBox(height: 16),
                  QuizExplanation(
                    explanation: widget.quiz.explanation,
                    logger: _logger,
                    keywords: widget.quiz.keywords,
                    quizId: widget.quiz.id,
                    subjectId: widget.subjectId,
                    quizTypeId: widget.quizTypeId,
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
      },
    );
  }

  void _resetQuiz() {
    setState(() {
      _selectedOptionIndex = null;
      _hasAnswered = false;
      _startTime = DateTime.now();
    });
    _userProvider.resetUserAnswers(widget.subjectId, widget.quizTypeId,
        quizId: widget.quiz.id);
    _logger.i('Quiz reset for: ${widget.quiz.id}');
  }

  void _selectOption(int index, UserProvider userProvider) {
    _logger.i('Selecting option $index for quiz ${widget.quiz.id}');
    // 사용자가 선택한 옵션이 없거나, quizpage가 아닐 때
    if (_selectedOptionIndex == null || !widget.isQuizPage) {
      setState(() {
        // 사용자가 선택한 옵션값을 받고
        _selectedOptionIndex = index;
        _hasAnswered = true; // 저장할 수 있게 함
      });

      final endTime = DateTime.now();
      final answerTime = endTime.difference(_startTime!);
      final isCorrect = index == widget.quiz.correctOptionIndex;

      // 값을 저장함 => 복습 간격 계산
      userProvider.updateUserQuizData(
        widget.subjectId,
        widget.quizTypeId,
        widget.quiz.id,
        isCorrect,
        answerTime: answerTime,
        selectedOptionIndex: index,
      );

      widget.onAnswerSelected?.call(index);

      _showAnswerSnackBar(isCorrect);

      _logger.i('User selected option $index. Correct: $isCorrect.');
    } else {
      _logger.i('Option already selected. Ignoring new selection.');
    }
  }

  void _showAnswerSnackBar(bool isCorrect) {
    String message;
    Color backgroundColor;

    // 정답일 때
    if (isCorrect) {
      message = '정답입니다! 🎉';
      backgroundColor = const Color.fromARGB(255, 144, 223, 146);
    } else {
      // 오답일 때
      message = '오답입니다. 다시 도전해보세요! 💪';
      backgroundColor = const Color.fromARGB(255, 218, 141, 135);
    }

    if (!widget.isQuizPage) {
      // quizpage가 아닐 때
      final reviewTimeString = _userProvider.getNextReviewTimeString(
        widget.subjectId,
        widget.quizTypeId,
        widget.quiz.id,
      );
      message += '\n다음 복습은 $reviewTimeString 후입니다.'; // snackbar에 복습 시간 표시
    }

    _logger.i(
        'Showing answer snackbar. IsCorrect: $isCorrect, IsQuizPage: ${widget.isQuizPage}');

    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: backgroundColor,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
