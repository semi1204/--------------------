import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../services/quiz_service.dart';
import 'accuracy_display.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'common_widgets.dart';
import 'markdown_widgets.dart';

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

  const QuizCard({
    super.key,
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
  });

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> {
  bool _hasAnswered = false;
  late final Logger _logger;
  late final QuizService _quizService;
  late final UserProvider _userProvider;
  DateTime? _startTime;

  Map<String, dynamic>? _cachedQuizData;

  @override
  void initState() {
    super.initState();
    _logger = Provider.of<Logger>(context, listen: false);
    _quizService = Provider.of<QuizService>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _logger.i('QuizCard initialized for quiz: ${widget.quiz.question}');
    _startTime = DateTime.now();

    _loadQuizData();
    // Set _hasAnswered based on whether there's a selected option
    _hasAnswered = widget.selectedOptionIndex != null;
  }

  Future<void> _loadQuizData() async {
    if (_userProvider.user != null) {
      _cachedQuizData =
          await _quizService.getUserQuizData(_userProvider.user!.uid);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    _logger.i('Building QuizCard for quiz: ${widget.quiz.question}');

    Widget content = Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            if (widget.quiz.keywords.isNotEmpty) ...[
              _buildKeywords(),
              const SizedBox(height: 12),
            ],
            _buildQuestion(),
            const SizedBox(height: 16),
            ..._buildOptions(),
            if (_hasAnswered) ...[
              const SizedBox(height: 16),
              _buildExplanation(),
            ],
            if (widget.isAdmin) _buildAdminActions(),
            if (widget.isIncorrectAnswersMode) _buildDeleteReviewButton(),
          ],
        ),
      ),
    );

    // 수정: isScrollable이 true일 경우 SingleChildScrollView로 감싸기
    return widget.isScrollable
        ? SingleChildScrollView(child: content)
        : content;
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Question ${widget.questionNumber}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            _buildAccuracyDisplay(),
            // 추가: 초기화 버튼
            if (widget.onResetQuiz != null)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _logger.i('Reset button pressed for quiz: ${widget.quiz.id}');
                  widget.onResetQuiz?.call();
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            _logger.i('Edit button pressed for quiz: ${widget.quiz.id}');
            widget.onEdit?.call();
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () {
            _logger.i('Delete button pressed for quiz: ${widget.quiz.id}');
            widget.onDelete?.call();
          },
        ),
      ],
    );
  }

  Widget _buildAccuracyDisplay() {
    if (_cachedQuizData != null) {
      final quizData = _cachedQuizData![widget.quiz.id];
      if (quizData != null) {
        final accuracy = quizData['accuracy'] ?? 0.0;
        return AccuracyDisplay(accuracy: accuracy);
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildKeywords() {
    return Wrap(
      spacing: 4.0,
      runSpacing: 2.0,
      children: widget.quiz.keywords
          .map((keyword) => _buildKeywordChip(keyword))
          .toList(),
    );
  }

  Widget _buildKeywordChip(String keyword) {
    return SizedBox(
      height: 24,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade100,
          foregroundColor: Colors.black,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: Size.zero,
        ),
        onPressed: () {
          _logger.i('Keyword tapped: $keyword');
        },
        child: Text(
          keyword,
          style: const TextStyle(fontSize: 10),
        ),
      ),
    );
  }

  // 수정: 마크다운 및 수식 지원 추가
  Widget _buildQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.quiz.imageUrl != null && widget.quiz.imageUrl!.isNotEmpty)
          NetworkImageWithLoader(
            imageUrl: widget.quiz.imageUrl!,
            width: double.infinity,
            height: 200,
          ),
        const SizedBox(height: 8),
        MarkdownRenderer(
          data: widget.quiz.question,
          logger: _logger,
        ),
      ],
    );
  }

  // 추가: 복습 카드 삭제 버튼
  Widget _buildDeleteReviewButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.delete),
      label: const Text('Delete Review'),
      onPressed: () {
        _logger.i('Delete review button pressed for quiz: ${widget.quiz.id}');
        showDialog(
          context: context,
          builder: (context) => ConfirmationDialog(
            title: 'Delete Review',
            content: 'Are you sure you want to delete this review?',
            onConfirm: widget.onDeleteReview ?? () {},
          ),
        );
      },
    );
  }

  List<Widget> _buildOptions() {
    return widget.quiz.options.asMap().entries.map((entry) {
      final index = entry.key;
      final option = entry.value;
      final isSelected = widget.selectedOptionIndex == index;
      final isCorrect = index == widget.quiz.correctOptionIndex;

      return InkWell(
        onTap: widget.selectedOptionIndex == null
            ? () => _selectOption(index)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              _buildOptionIcon(isSelected, isCorrect),
              const SizedBox(width: 8),
              Expanded(
                child: MarkdownRenderer(
                  data: option,
                  logger: _logger,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildOptionIcon(bool isSelected, bool isCorrect) {
    if (_hasAnswered) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCorrect
              ? Colors.green
              : (isSelected ? Colors.red : Colors.transparent),
          border: Border.all(
            color: isCorrect
                ? Colors.green
                : (isSelected ? Colors.red : Colors.grey),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            isCorrect ? 'O' : (isSelected ? 'X' : ''),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else {
      return Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: Colors.grey,
      );
    }
  }

  Color? _getOptionTextColor(bool isSelected, bool isCorrect) {
    if (_hasAnswered && isCorrect) {
      return Colors.green;
    }
    return null;
  }

  FontWeight _getOptionFontWeight(bool isSelected, bool isCorrect) {
    if (isSelected || (_hasAnswered && isCorrect)) {
      return FontWeight.bold;
    }
    return FontWeight.normal;
  }

  TextDecoration? _getOptionDecoration(bool isSelected, bool isCorrect) {
    if (_hasAnswered && isSelected && !isCorrect) {
      return TextDecoration.lineThrough;
    }
    return null;
  }

  Color? _getOptionDecorationColor(bool isSelected, bool isCorrect) {
    if (_hasAnswered && isSelected && !isCorrect) {
      return Colors.red;
    }
    return null;
  }

  Widget _buildExplanation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Explanation',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        MarkdownRenderer(
          data: widget.quiz.explanation,
          logger: _logger,
        ),
      ],
    );
  }

  void _selectOption(int index) {
    if (_hasAnswered && !widget.isIncorrectAnswersMode) {
      return; // Prevent re-selection if already answered in normal quiz mode
    }

    final endTime = DateTime.now();
    final answerTime = endTime.difference(_startTime!);

    _logger.i(
        'Option selected for quiz: ${widget.quiz.question}, selected option index: $index, answer time: $answerTime');

    final isCorrect = index == widget.quiz.correctOptionIndex;

    setState(() {
      _hasAnswered = true;
    });

    widget.onAnswerSelected?.call(index);

    if (_userProvider.user != null && !widget.isIncorrectAnswersMode) {
      _userProvider.updateUserQuizData(widget.quiz.id, isCorrect,
          answerTime: answerTime);
    } else {
      _logger.w(
          'User is not logged in or in Incorrect Answers mode. Quiz data not updated.');
    }

    if (!widget.isIncorrectAnswersMode) {
      _showAnswerSnackBar(isCorrect);
    }
  }

  void _showAnswerSnackBar(bool isCorrect) {
    final reviewTimeString = kDebugMode
        ? _userProvider.getDebugNextReviewTimeString(widget.quiz.id)
        : _userProvider.getNextReviewTimeString(widget.quiz.id);

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
