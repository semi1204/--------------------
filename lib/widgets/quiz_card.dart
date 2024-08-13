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
import 'package:flutter/foundation.dart';

abstract class BaseQuizCard extends StatefulWidget {
  final Quiz quiz;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final int questionNumber;
  final String subjectId;
  final String quizTypeId;
  final String nextReviewDate;

  const BaseQuizCard({
    super.key,
    required this.quiz,
    this.isAdmin = false,
    this.onEdit,
    this.onDelete,
    required this.questionNumber,
    required this.subjectId,
    required this.quizTypeId,
    required this.nextReviewDate,
  });
}

//-----------QuizPageCard-----------  //
class QuizPageCard extends BaseQuizCard {
  final int? selectedOptionIndex;
  final Function(int)? onAnswerSelected;
  final VoidCallback? onResetQuiz;
  final bool isQuizPage;
  final bool rebuildExplanation;

  const QuizPageCard({
    super.key,
    required super.quiz,
    super.isAdmin,
    super.onEdit,
    super.onDelete,
    required super.questionNumber,
    required super.subjectId,
    required super.quizTypeId,
    required super.nextReviewDate,
    this.selectedOptionIndex,
    this.onAnswerSelected,
    this.onResetQuiz,
    required this.isQuizPage,
    required this.rebuildExplanation,
  });

  @override
  State<QuizPageCard> createState() => _QuizPageCardState();
}

//-----------ReviewPageCard-----------//
class ReviewPageCard extends BaseQuizCard {
  final Function(int) onAnswerSelected;
  final VoidCallback? onDeleteReview;
  final Widget Function() buildFeedbackButtons;

  const ReviewPageCard({
    super.key,
    required super.quiz,
    super.isAdmin,
    super.onEdit,
    super.onDelete,
    required super.questionNumber,
    required super.subjectId,
    required super.quizTypeId,
    required super.nextReviewDate,
    required this.onAnswerSelected,
    this.onDeleteReview,
    required this.buildFeedbackButtons,
  });

  @override
  State<ReviewPageCard> createState() => _ReviewPageCardState();
}

// 퀴즈 페이지 카드
class _QuizPageCardState extends State<QuizPageCard> {
  late final Logger _logger;
  late final UserProvider userProvider;
  DateTime? _startTime;
  int? _selectedOptionIndex;
  bool _hasAnswered = false;

  @override
  void initState() {
    super.initState();
    _logger = Provider.of<Logger>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    _startTime = DateTime.now();
    _loadUserAnswer();

    _logger.d('QuizPageCard initialized: quizId=${widget.quiz.id}');
  }

  void _loadUserAnswer() {
    _selectedOptionIndex = widget.selectedOptionIndex;
    _hasAnswered = _selectedOptionIndex != null;

    _logger.d(
        'Loaded user answer: quizId=${widget.quiz.id}, selectedOptionIndex=$_selectedOptionIndex, hasAnswered=$_hasAnswered');
  }

  @override
  void didUpdateWidget(QuizPageCard oldWidget) {
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
        // ---- TODO : quizCard에서는 복습 버튼을 눌러야 복습을 시작함. 복습계산을 하지않음. 무조건 지우지말고, 이 변수 존재이유를 확인해야함 ---------//
        final nextReviewDate = userProvider.getNextReviewDate(
          widget.subjectId,
          widget.quizTypeId,
          widget.quiz.id,
        );
        final isInReviewList =
            nextReviewDate != null && nextReviewDate.isAfter(DateTime.now());

        _logger.d(
            '퀴즈 페이지 카드 빌드: quizId=${widget.quiz.id}, isInReviewList=$isInReviewList');

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
                  onResetQuiz: () {
                    setState(() {
                      _selectedOptionIndex = null;
                      _hasAnswered = false;
                      _startTime = DateTime.now();
                    });
                    widget.onResetQuiz?.call();
                  },
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
                    rebuildTrigger: widget.rebuildExplanation,
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

  // 퀴즈카드의 옵션을 선택했을 때 실행되는 함수
  void _selectOption(int index, UserProvider userProvider) {
    _logger.i('퀴즈 페이지 카드: 옵션 $index 선택: quizId=${widget.quiz.id}');
    if (_selectedOptionIndex == null) {
      setState(() {
        _selectedOptionIndex = index;
        _hasAnswered = true;
      });

      final endTime = DateTime.now();
      final answerTime = endTime.difference(_startTime!);
      final isCorrect = index == widget.quiz.correctOptionIndex;

      //데이터를 updateUserQuizData에 전달
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

      _logger.i('퀴즈 페이지 카드: 유저가 옵션 $index 선택. 정답: $isCorrect.');
    } else {
      _logger.i('퀴즈 페이지 카드: 옵션이 이미 선택되었습니다. 새로운 선택을 무시합니다.');
    }
  }

  void _showAnswerSnackBar(bool isCorrect) {
    String message = isCorrect ? '정답입니다! 🎉' : '오답입니다. 다시 도전해보세요! 💪';
    Color backgroundColor = isCorrect
        ? const Color.fromARGB(255, 144, 223, 146)
        : const Color.fromARGB(255, 218, 141, 135);

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

// 복습 페이지 카드
// TODO : MarkForReview가 된 퀴즈는 복습카드로 넘어가고, 복습페이지에서 보이기 시작하는지 확인 ---------//
class _ReviewPageCardState extends State<ReviewPageCard> {
  late final Logger _logger;
  late final UserProvider _userProvider;
  int? _selectedOptionIndex;
  bool _hasAnswered = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _logger = Provider.of<Logger>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // -- TODO : 복습카드의 데이터를 quiz_service. getQuizzesForReview에서 가져오는지 확인 ---------//
        final nextReviewDate = userProvider.getNextReviewDate(
          widget.subjectId,
          widget.quizTypeId,
          widget.quiz.id,
        );
        final isInReviewList =
            nextReviewDate != null && nextReviewDate.isAfter(DateTime.now());

        _logger.d(
            '복습 페이지 카드 빌드: quizId=${widget.quiz.id}, isInReviewList=$isInReviewList');

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
                  onResetQuiz: () {}, // ReviewPageCard에서는 리셋 기능을 제공하지 않습니다.
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
                  isQuizPage: false,
                  onSelectOption: (index) => _selectOption(index, userProvider),
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
                    rebuildTrigger: false,
                  ),
                  const SizedBox(height: 16),
                  widget.buildFeedbackButtons(),
                ],
                if (widget.isAdmin)
                  QuizAdminActions(
                    onEdit: widget.onEdit,
                    onDelete: widget.onDelete,
                  ),
                // Fixed : reviewpage에서 _deleteReview 메서드 호출되는지, 어떻게 데이터 구조를 일치시키는지 확인, 중복되는 부부은 삭제---------//
                // Removed the onDeleteReview callback and the _deleteReview method
                // Updated the UI to use the functionality from the Explanation page to remove the quiz from the review list
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectOption(int index, UserProvider userProvider) {
    if (_selectedOptionIndex == null) {
      setState(() {
        _selectedOptionIndex = index;
        _hasAnswered = true;
      });

      final endTime = DateTime.now();
      final answerTime = endTime.difference(_startTime!);
      final isCorrect = index == widget.quiz.correctOptionIndex;

      userProvider.updateUserQuizData(
        widget.subjectId,
        widget.quizTypeId,
        widget.quiz.id,
        isCorrect,
        answerTime: answerTime,
        selectedOptionIndex: index,
      );

      widget.onAnswerSelected(index);

      _showAnswerSnackBar(isCorrect);

      _logger.i('복습 페이지 카드: 유저가 옵션 $index 선택. 정답: $isCorrect.');
    } else {
      _logger.i('복습 페이지 카드: 옵션이 이미 선택되었습니다. 새로운 선택을 무시합니다.');
    }
  }

  void _showAnswerSnackBar(bool isCorrect) {
    String message = isCorrect ? '정답입니다! 🎉' : '오답입니다. 다시 도전해보세요! 💪';
    Color backgroundColor = isCorrect
        ? const Color.fromARGB(255, 144, 223, 146)
        : const Color.fromARGB(255, 218, 141, 135);

    final reviewTimeString = _userProvider.formatNextReviewDate(
      widget.subjectId,
      widget.quizTypeId,
      widget.quiz.id,
    );
    if (kDebugMode) {
      message += '\n다음 복습은 $reviewTimeString 후입니다. (디버그 모드)';
    } else {
      message += '\n다음 복습은 $reviewTimeString 후입니다.';
    }

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
