import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:markdown_widget/markdown_widget.dart';

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
    return MarkdownWidget(
      data: question,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }
}
