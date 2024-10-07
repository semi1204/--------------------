import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/models/quiz.dart';
import 'package:logger/logger.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:nursing_quiz_app_6/utils/constants.dart';

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
        final isSelected = selectedOptionIndex == index;
        final isCorrect = index == quiz.correctOptionIndex;
        final bool showSelection = isQuizPage ? isSelected : false;

        final optionText =
            (hasAnswered && isSelected && !isCorrect) ? '~~$option~~' : option;

        return InkWell(
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
                  child: MarkdownWidget(
                    data: optionText,
                    config: MarkdownConfig(
                      configs: [
                        PConfig(
                          textStyle: TextStyle(
                            color: _getOptionTextColor(
                                showSelection, isSelected, isCorrect),
                          ),
                        ),
                      ],
                    ),
                    markdownGenerator: MarkdownGenerator(
                      generators: [
                        SpanNodeGeneratorWithTag(
                          tag: 'p',
                          generator: (e, config, visitor) {
                            return ParagraphNode(
                              PConfig(
                                textStyle: TextStyle(
                                  color: _getOptionTextColor(
                                      showSelection, isSelected, isCorrect),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
