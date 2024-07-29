import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../models/quiz.dart';

class QuizCard extends StatefulWidget {
  final Quiz quiz;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const QuizCard({
    super.key,
    required this.quiz,
    this.isAdmin = false,
    this.onEdit,
    this.onDelete,
  });

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
            if (widget.isAdmin)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      _logger
                          .i('Edit button pressed for quiz: ${widget.quiz.id}');
                      widget.onEdit?.call();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      _logger.i(
                          'Delete button pressed for quiz: ${widget.quiz.id}');
                      widget.onDelete?.call();
                    },
                  ),
                ],
              ),
            if (widget.quiz.keywords.isNotEmpty) ...[
              Wrap(
                spacing: 4.0,
                runSpacing: 2.0,
                children: widget.quiz.keywords
                    .map((keyword) => SizedBox(
                          height: 24,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade100,
                              foregroundColor: Colors.black,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
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
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            // 수정: 볼드 스타일 제거 및 마크다운 완전 지원
            MarkdownBody(
              data: widget.quiz.question,
              selectable: true,
              extensionSet: md.ExtensionSet([
                md.TableSyntax(),
              ], md.ExtensionSet.gitHubFlavored.inlineSyntaxes),
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 16),
                tableBody: const TextStyle(fontSize: 14),
                tableBorder: TableBorder.all(color: Colors.grey),
                tableColumnWidth: const FixedColumnWidth(120),
                tableCellsPadding: const EdgeInsets.all(4),
              ),
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
                        child: MarkdownBody(
                          data: option,
                          selectable: true,
                          extensionSet: md.ExtensionSet([
                            md.TableSyntax(),
                          ], md.ExtensionSet.gitHubFlavored.inlineSyntaxes),
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: _hasAnswered && isCorrect
                                  ? Colors.green
                                  : null,
                              fontWeight:
                                  isSelected || (_hasAnswered && isCorrect)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              decoration:
                                  _hasAnswered && isSelected && !isCorrect
                                      ? TextDecoration.lineThrough
                                      : null,
                              decorationColor:
                                  _hasAnswered && isSelected && !isCorrect
                                      ? Colors.red
                                      : null,
                              decorationThickness: 2.0,
                            ),
                            tableBody: const TextStyle(fontSize: 14),
                            tableBorder: TableBorder.all(color: Colors.grey),
                            tableColumnWidth: const FixedColumnWidth(120),
                            tableCellsPadding: const EdgeInsets.all(4),
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
              // 수정: Explanation 위젯 추가
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
              // 수정: 설명 부분을 마크다운으로 렌더링
              MarkdownBody(
                data: widget.quiz.explanation,
                selectable: true,
                extensionSet: md.ExtensionSet([
                  md.TableSyntax(),
                ], md.ExtensionSet.gitHubFlavored.inlineSyntaxes),
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 14),
                  tableBody: const TextStyle(fontSize: 14),
                  tableBorder: TableBorder.all(color: Colors.grey),
                  tableColumnWidth: const FixedColumnWidth(120),
                  tableCellsPadding: const EdgeInsets.all(4),
                ),
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
    _logger.i(
        'Snackbar shown for quiz answer: ${isCorrect ? 'Correct' : 'Incorrect'}');
  }
}
