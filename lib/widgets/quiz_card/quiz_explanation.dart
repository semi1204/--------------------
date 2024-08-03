import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/markdown_widgets.dart';

class QuizExplanation extends StatelessWidget {
  final String explanation;
  final Logger logger;

  const QuizExplanation({
    Key? key,
    required this.explanation,
    required this.logger,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Explanation',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        MarkdownRenderer(
          data: explanation,
          logger: logger,
        ),
      ],
    );
  }
}
