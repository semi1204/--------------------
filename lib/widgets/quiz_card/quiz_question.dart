import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'markdown_widgets.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          child: Material(
            elevation: 1,
            borderRadius: BorderRadius.circular(5),
            color: Theme.of(context).brightness == Brightness.light
                ? Theme.of(context).cardColor.withOpacity(0.1)
                : Theme.of(context).cardColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(0.0),
              child: MarkdownRenderer(
                data: question,
                logger: logger,
              ),
            ),
          ),
        );
      },
    );
  }
}
