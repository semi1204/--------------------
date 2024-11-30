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
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          width: constraints.maxWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            boxShadow: [
              BoxShadow(
                color:
                    isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(0.0),
            child: MarkdownRenderer(
              data: question,
              logger: logger,
            ),
          ),
        );
      },
    );
  }
}
