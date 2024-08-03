import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/markdown_widgets.dart';

class QuizQuestion extends StatelessWidget {
  final String question;
  final Logger logger;

  const QuizQuestion({
    super.key,
    required this.question,
    required this.logger,
  });

  @override
  Widget build(BuildContext context) {
    return MarkdownRenderer(
      data: question,
      logger: logger,
    );
  }
}
