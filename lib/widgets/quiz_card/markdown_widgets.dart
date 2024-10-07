import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:nursing_quiz_app_6/providers/theme_provider.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card/network_image_with_loader.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/parser.dart' as htmlparser;
import 'package:html/dom.dart' as dom;

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
            SpanNodeGeneratorWithTag(
              tag: 'html',
              generator: (e, config, visitor) {
                return HtmlNode(e.textContent, scaleFactor, context);
              },
            ),
          ],
          inlineSyntaxList: [
            CustomInlineMathSyntax(),
            CustomKoreanFractionSyntax(),
            CustomHtmlSyntax(),
          ],
        );

        // HTML 사전 처리
        final processedData = _preProcessHtml(data);

        final List<Widget> markdownWidgets = markdownGenerator.buildWidgets(
          processedData,
          config: config,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: markdownWidgets,
        );
      },
    );
  }

  String _preProcessHtml(String input) {
    // <br> 태그를 Markdown 줄바꿈으로 변환 (테이블 내부 제외)
    input = _processBrTags(input);

    // 테이블 처리
    input = _processTables(input);

    // 다른 HTML 태그를 처리
    final document = htmlparser.parse(input);
    String processedHtml = '';

    void _processNode(dom.Node node) {
      if (node is dom.Element) {
        if (node.localName == 'table') {
          processedHtml += node.outerHtml;
        } else {
          processedHtml += '<html>${node.outerHtml}</html>';
        }
        if (node.localName != 'table') {
          node.nodes.forEach(_processNode);
        }
      } else if (node is dom.Text) {
        processedHtml += node.text;
      } else {
        // Handle other types of nodes if necessary
        node.nodes.forEach(_processNode);
      }
    }

    document.body?.nodes.forEach(_processNode);

    return processedHtml;
  }

  String _processBrTags(String input) {
    final RegExp tableRegExp = RegExp(r'<table[\s\S]*?<\/table>',
        multiLine: true, caseSensitive: false);
    final matches = tableRegExp.allMatches(input);

    if (matches.isEmpty) {
      return input.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    }

    final List<String> parts = [];
    int lastEnd = 0;

    for (final match in matches) {
      // 테이블 앞부분 처리
      if (match.start > lastEnd) {
        parts.add(input
            .substring(lastEnd, match.start)
            .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n'));
      }
      // 테이블 부분은 그대로 추가
      parts.add(match.group(0)!);
      lastEnd = match.end;
    }

    // 마지막 테이블 이후 부분 처리
    if (lastEnd < input.length) {
      parts.add(input
          .substring(lastEnd)
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n'));
    }

    return parts.join();
  }

  String _processTables(String input) {
    final RegExp tableRegExp = RegExp(r'<table[\s\S]*?<\/table>',
        multiLine: true, caseSensitive: false);
    return input.replaceAllMapped(tableRegExp, (match) {
      final table = match.group(0)!;
      final processedTable =
          table.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '<br>');
      return '<html>$processedTable</html>';
    });
  }
}

class HtmlNode extends SpanNode {
  final String htmlContent;
  final double scaleFactor;
  final BuildContext context;

  HtmlNode(this.htmlContent, this.scaleFactor, this.context);

  @override
  InlineSpan build() {
    return WidgetSpan(
      child: HtmlWidget(
        htmlContent,
        textStyle: TextStyle(fontSize: 16 * scaleFactor),
        customWidgetBuilder: (dom.Element element) {
          if (element.localName == 'img') {
            final String? src = element.attributes['src'];
            if (src != null) {
              return NetworkImageWithLoader(
                imageUrl: src,
                fit: BoxFit.contain,
                logger: Logger(),
                width: MediaQuery.of(context).size.width,
              );
            }
          }
          return null;
        },
        customStylesBuilder: (element) {
          if (element.localName == 'table') {
            return {'border-collapse': 'collapse', 'width': '100%'};
          }
          if (element.localName == 'td' || element.localName == 'th') {
            return {'border': '1px solid black', 'padding': '8px'};
          }
          return null;
        },
      ),
    );
  }
}

class ContentItem {
  final String content;
  final bool isHtml;

  ContentItem(this.content, this.isHtml);
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

class CustomHtmlSyntax extends md.InlineSyntax {
  CustomHtmlSyntax()
      : super(r'<(table|p|div|h[1-6])[\s\S]*?<\/\1>', caseSensitive: false);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final htmlContent = match[0]!;
    final element = md.Element.text('html', htmlContent);
    parser.addNode(element);
    return true;
  }
}
