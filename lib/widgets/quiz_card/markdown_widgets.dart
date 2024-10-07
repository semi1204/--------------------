import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:nursing_quiz_app_6/providers/theme_provider.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/network_image_with_loader.dart';

class MarkdownRenderer extends StatelessWidget {
  final String data;
  final Logger logger;

  const MarkdownRenderer({
    super.key,
    required this.data,
    required this.logger,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final scaleFactor = themeProvider.textScaleFactor;

        final config = MarkdownConfig(
          configs: [
            PConfig(textStyle: TextStyle(fontSize: 16 * scaleFactor)),
            H1Config(
                style: TextStyle(
                    fontSize: 32 * scaleFactor, fontWeight: FontWeight.bold)),
            H2Config(
                style: TextStyle(
                    fontSize: 24 * scaleFactor, fontWeight: FontWeight.bold)),
            H3Config(
                style: TextStyle(
                    fontSize: 18.72 * scaleFactor,
                    fontWeight: FontWeight.bold)),
            H4Config(
                style: TextStyle(
                    fontSize: 16 * scaleFactor, fontWeight: FontWeight.bold)),
            H5Config(
                style: TextStyle(
                    fontSize: 13.28 * scaleFactor,
                    fontWeight: FontWeight.bold)),
            H6Config(
                style: TextStyle(
                    fontSize: 10.72 * scaleFactor,
                    fontWeight: FontWeight.bold)),
            ListConfig(
              marker: (isOrdered, depth, index) {
                return Text(
                  isOrdered ? '${index + 1}.' : '•',
                  style: TextStyle(fontSize: 16 * scaleFactor),
                );
              },
            ),
            ImgConfig(
              builder: (url, attributes) {
                return FittedBox(
                  fit: BoxFit.fitWidth,
                  child: NetworkImageWithLoader(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    logger: logger,
                    width: MediaQuery.of(context).size.width,
                  ),
                );
              },
            ),
          ],
        );

        final markdownGenerator = MarkdownGenerator(
          generators: [
            SpanNodeGeneratorWithTag(
              tag: 'math',
              generator: (e, config, visitor) {
                return MathNode(e.textContent, scaleFactor);
              },
            ),
          ],
          inlineSyntaxList: [
            CustomInlineMathSyntax(),
            CustomKoreanFractionSyntax(),
          ],
        );

        final List<Widget> markdownWidgets = markdownGenerator.buildWidgets(
          data,
          config: config,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: markdownWidgets,
        );
      },
    );
  }
}

class MathNode extends SpanNode {
  final String mathText;
  final double scaleFactor;

  MathNode(this.mathText, this.scaleFactor);

  @override
  InlineSpan build() {
    return WidgetSpan(
      child: Math.tex(
        mathText,
        mathStyle: MathStyle.display,
        textStyle: TextStyle(fontSize: 16 * scaleFactor),
      ),
    );
  }
}

class CustomInlineMathSyntax extends md.InlineSyntax {
  CustomInlineMathSyntax() : super(r'\$([^$\n]+)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('math', match[1]!));
    return true;
  }
}

class CustomKoreanFractionSyntax extends md.InlineSyntax {
  CustomKoreanFractionSyntax()
      : super(r'\{([\p{Hangul}\s]+)\s*/\s*([\p{Hangul}\s]+)\}');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('math', '\\frac{${match[1]}}{${match[2]}}');
    parser.addNode(element);
    return true;
  }
}
