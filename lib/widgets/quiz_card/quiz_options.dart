import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/models/quiz.dart';
import 'package:logger/logger.dart';

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
        final bool isSelectable =
            !isQuizPage || hasAnswered; // 퀴즈 페이지가 아니거나 이미 답변한 경우 선택 가능

        // 로그 추가
        logger.d(
            '옵션 $index: 선택됨=$isSelected, 정답=$isCorrect, 표시=$showSelection, 선택가능=$isSelectable');

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
                  child: Text(
                    option,
                    style: TextStyle(
                      decoration: hasAnswered && isSelected && !isCorrect
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: Colors.black.withOpacity(0.4),
                      decorationThickness: 2,
                      color: _getOptionTextColor(
                          showSelection, isSelected, isCorrect),
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
      return Colors.green.withOpacity(0.2);
    if (isSelected) return Colors.red.withOpacity(0.2);
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
