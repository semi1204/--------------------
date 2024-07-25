import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../models/quiz.dart';

class QuizCard extends StatefulWidget {
  final Quiz quiz;

  const QuizCard({super.key, required this.quiz});

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> {
  int? _selectedOptionIndex;
  bool _hasAnswered = false;
  late final Logger _logger;

  @override
  void initState() {
    super.initState();
    _logger = Provider.of<Logger>(context, listen: false);
    _logger.i('QuizCard initialized for quiz: ${widget.quiz.question}');
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
            if (widget.quiz.keywords.isNotEmpty) ...[
              Wrap(
                spacing: 4.0, // 버튼 사이의 가로 간격 줄임
                runSpacing: 2.0, // 버튼 사이의 세로 간격 줄임
                children: widget.quiz.keywords
                    .map((keyword) => SizedBox(
                          height: 24, // 버튼의 높이 고정
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade100,
                              foregroundColor: Colors.black,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12.0), // 모서리 반경 줄임
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2), // 패딩 더 줄임
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: Size.zero, // 최소 크기 제한 제거
                            ),
                            onPressed: () {},
                            child: Text(
                              keyword,
                              style:
                                  const TextStyle(fontSize: 10), // 폰트 크기 더 줄임
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12), // 키워드와 질문 사이 간격 줄임
            ],
            Text(
              widget.quiz.question,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...widget.quiz.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = _selectedOptionIndex == index;
              final isCorrect = index == widget.quiz.correctOptionIndex;

              return InkWell(
                onTap:
                    !_hasAnswered ? () => _selectOption(index, context) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      if (_hasAnswered)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCorrect
                                ? Colors.green
                                : (isSelected
                                    ? Colors.red
                                    : Colors.transparent),
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
                        )
                      else
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: Colors.grey,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            color:
                                _hasAnswered && isCorrect ? Colors.green : null,
                            fontWeight:
                                isSelected || (_hasAnswered && isCorrect)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            decoration: _hasAnswered && isSelected && !isCorrect
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor:
                                _hasAnswered && isSelected && !isCorrect
                                    ? Colors.red
                                    : null,
                            decorationThickness: 2.0, // 취소선 두께 증가
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (_hasAnswered) ...[
              const SizedBox(height: 16),
              Text(
                'Explanation: ${widget.quiz.explanation}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _selectOption(int index, BuildContext context) {
    setState(() {
      _selectedOptionIndex = index;
      _hasAnswered = true;
    });
    _logger.i(
        'Option selected for quiz: ${widget.quiz.question}, selected option index: $index');

    final isCorrect = index == widget.quiz.correctOptionIndex;
    final snackBar = SnackBar(
      content: Row(
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
      backgroundColor: isCorrect
          ? const Color.fromARGB(255, 144, 223, 146)
          : const Color.fromARGB(255, 218, 141, 135),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
