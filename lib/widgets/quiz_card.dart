import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../services/quiz_service.dart';
import 'accuracy_display.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class QuizCard extends StatefulWidget {
  final Quiz quiz;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final int questionNumber;

  const QuizCard({
    Key? key,
    required this.quiz,
    this.isAdmin = false,
    this.onEdit,
    this.onDelete,
    required this.questionNumber,
  }) : super(key: key);

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> {
  int? _selectedOptionIndex;
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

    // 추가: 초기화 시 퀴즈 데이터 로드
    _loadQuizData();
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

    return Card(
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Question ${widget.questionNumber}', // widget.questionNumber 사용
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        _buildAccuracyDisplay(),
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
    // 수정: 캐시된 데이터 사용
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

  Widget _buildQuestion() {
    return Text(
      widget.quiz.question,
      style: const TextStyle(fontSize: 16),
    );
  }

  List<Widget> _buildOptions() {
    return widget.quiz.options.asMap().entries.map((entry) {
      final index = entry.key;
      final option = entry.value;
      final isSelected = _selectedOptionIndex == index;
      final isCorrect = index == widget.quiz.correctOptionIndex;

      return InkWell(
        onTap: !_hasAnswered ? () => _selectOption(index) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              _buildOptionIcon(isSelected, isCorrect),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    color: _getOptionTextColor(isSelected, isCorrect),
                    fontWeight: _getOptionFontWeight(isSelected, isCorrect),
                    decoration: _getOptionDecoration(isSelected, isCorrect),
                    decorationColor:
                        _getOptionDecorationColor(isSelected, isCorrect),
                    decorationThickness: 2.0,
                  ),
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
        Text(
          widget.quiz.explanation,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  void _selectOption(int index) {
    final endTime = DateTime.now(); // 수정: 변수명 수정
    final answerTime = endTime.difference(_startTime!);

    setState(() {
      _selectedOptionIndex = index;
      _hasAnswered = true;
    });
    _logger.i(
        'Option selected for quiz: ${widget.quiz.question}, selected option index: $index, answer time: $answerTime');

    final isCorrect = index == widget.quiz.correctOptionIndex;

    if (_userProvider.user != null) {
      _userProvider.updateUserQuizData(widget.quiz.id, isCorrect,
          answerTime: answerTime);
    } else {
      _logger.w('User is not logged in. Quiz data not updated.');
    }

    _showAnswerSnackBar(isCorrect);

    // 답변 후 타이머 리셋
    _startTime = DateTime.now();
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
