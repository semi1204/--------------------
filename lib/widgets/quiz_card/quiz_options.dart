import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/models/quiz.dart';
import 'package:logger/logger.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Add this import
import 'package:nursing_quiz_app_6/utils/constants.dart';
import 'markdown_widgets.dart'; // Add this import

//옵션도 마크다운을 사용할 수 있음.
class QuizOptions extends StatelessWidget {
  final Quiz quiz;
  final int? selectedOptionIndex;
  final bool hasAnswered;
  final bool isQuizPage;
  final Function(int) onSelectOption;
  final Logger logger;

  const QuizOptions({
    super.key,
    required this.quiz,
    required this.selectedOptionIndex,
    required this.hasAnswered,
    required this.isQuizPage,
    required this.onSelectOption,
    required this.logger,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: quiz.options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final isSelected = selectedOptionIndex == index; // 사용자가 선택한 옵션값을 받고
        final isCorrect = index == quiz.correctOptionIndex; // 정답인지 확인
        final bool showSelection =
            isQuizPage ? isSelected : false; // 퀴즈페이지일 때만 선택된 옵션을 보여줌
        // final bool isSelectable =
        //     !isQuizPage || hasAnswered; // 퀴즈 페이지가 아니거나 이미 답변한 경우 선택 가능

        // 로그 추가
        // logger.d(
        //     '옵션 $index: 선택됨=$isSelected, 정답=$isCorrect, 표시=$showSelection, 선택가능=$isSelectable');

        // Apply strikethrough in Markdown if necessary
        final optionText = (hasAnswered && isSelected && !isCorrect)
            ? '~~$option~~'
            : option; // 오답이면 옵션에 줄긋기

        return InkWell(
          // 퀴즈 페이지가 아니거나 아직 답변하지 않은 경우 선택 가능
          onTap: (!isQuizPage || !hasAnswered)
              ? () => onSelectOption(index)
              : null,
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: _getOptionColor(showSelection, isSelected, isCorrect),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                Icon(
                  _getOptionIcon(showSelection, isSelected, isCorrect),
                  color: _getOptionIconColor(isSelected, isCorrect),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // Replace Text widget with MarkdownRenderer
                  child: MarkdownRenderer(
                    data: optionText,
                    logger: logger,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: _getOptionTextColor(
                            showSelection, isSelected, isCorrect),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getOptionColor(bool showSelection, bool isSelected, bool isCorrect) {
    if (!hasAnswered) return Colors.transparent;
    if (isCorrect && (hasAnswered || showSelection))
      return CORRECT_OPTION_COLOR;
    if (isSelected) return INCORRECT_OPTION_COLOR;
    return Colors.transparent;
  }

  IconData _getOptionIcon(bool showSelection, bool isSelected, bool isCorrect) {
    if (!hasAnswered && !showSelection) return Icons.radio_button_unchecked;
    if (isCorrect && (hasAnswered || showSelection)) return Icons.check_circle;
    if (isSelected) return Icons.cancel;
    return Icons.radio_button_unchecked;
  }

  Color _getOptionIconColor(bool isSelected, bool isCorrect) {
    if (!hasAnswered) return Colors.grey;
    if (isCorrect) return const Color.fromARGB(255, 134, 210, 137);
    if (isSelected) return const Color.fromARGB(255, 232, 105, 96);
    return Colors.grey;
  }

  Color _getOptionTextColor(
      bool showSelection, bool isSelected, bool isCorrect) {
    if (!hasAnswered && !showSelection) return Colors.black;
    if (isCorrect && (hasAnswered || showSelection)) return Colors.black;
    return Colors.black;
  }
}
