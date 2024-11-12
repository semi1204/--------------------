import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/models/quiz.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/utils/constants.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/markdown_widgets.dart';

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
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: hasAnswered ? 0.7 : 1.0,
      child: Container(
        key: ValueKey('${quiz.id}_${selectedOptionIndex ?? "none"}'),
        child: quiz.isOX
            ? _buildOXOptions()
            : Column(children: _buildRegularOptions()),
      ),
    );
  }

  Widget _buildOXOptions() {
    return Row(
      children: ['O', 'X'].asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildOptionButton(index, option),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildRegularOptions() {
    return quiz.options.asMap().entries.map((entry) {
      final index = entry.key;
      final option = entry.value;
      return _buildOptionButton(index, option);
    }).toList();
  }

  Widget _buildOptionButton(int index, String option) {
    final isSelected = selectedOptionIndex == index;
    final isCorrect = index == quiz.correctOptionIndex;
    final bool showSelection = isQuizPage ? isSelected : false;

    final optionText =
        (hasAnswered && isSelected && !isCorrect) ? '~~$option~~' : option;

    return InkWell(
      onTap: (!isQuizPage || !hasAnswered) ? () => onSelectOption(index) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
              child: MarkdownRenderer(
                data: optionText,
                logger: logger,
              ),
            ),
          ],
        ),
      ),
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
}
