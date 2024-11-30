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
              marginLeft: 32.0,
              marginBottom: 8.0,
              marker: (isOrdered, depth, index) {
                return Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: isOrdered
                      ? null
                      : BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                        ),
                  child: Center(
                    child: Text(
                      isOrdered ? '${index + 1}.' : '•',
                      style: TextStyle(
                        fontSize: 16 * scaleFactor,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
            // 테이블 처리
            TableConfig(
              columnWidths: const {}, // 빈 맵을 사용
              defaultColumnWidth: const IntrinsicColumnWidth(flex: 1),
              // 테두리 스타일 추가
              border: TableBorder.all(
                color: Theme.of(context)
                    .dividerColor
                    .withOpacity(0.5), // 현재 테마의 dividerColor를 50% 투명도로 설정
                width: 1,
              ),
              wrapper: (Widget table) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                        maxWidth: constraints.maxWidth,
                      ),
                      child: table,
                    );
                  },
                );
              },
              headerStyle: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16 * scaleFactor,
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black
                    : Colors.white,
              ),
              bodyStyle: TextStyle(
                fontSize: 16 * scaleFactor,
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black
                    : Colors.white,
              ),
              headPadding: const EdgeInsets.all(12),
              bodyPadding: const EdgeInsets.all(12),
              headerRowDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
              ),
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
            SpanNodeGeneratorWithTag(
              tag: 'divider',
              generator: (e, config, visitor) {
                return DividerNode();
              },
            ),
            SpanNodeGeneratorWithTag(
              tag: 'highlight',
              generator: (e, config, visitor) => HighlightNode(
                e.textContent,
                color: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
            ),
          ],
          inlineSyntaxList: [
            CustomInlineMathSyntax(),
            CustomKoreanFractionSyntax(),
            CustomHtmlSyntax(),
            CustomDividerSyntax(),
            CustomHighlightSyntax(),
          ],
        );

        // HTML 사전 처리
        final processedData = _preProcessHtml(data);

        final List<Widget> markdownWidgets = markdownGenerator.buildWidgets(
          processedData,
          config: config,
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: markdownWidgets,
          ),
        );
      },
    );
  }

  String _preProcessHtml(String input) {
    input = input.replaceAllMapped(
      RegExp(r'==(.+?)=='),
      (match) => '{{highlight}}${match[1]}{{/highlight}}',
    );

    input = input.replaceAllMapped(
        RegExp(r'([^\n]*)\n---\s*$', multiLine: true),
        (Match match) => '${match.group(1)}\n{{divider}}');

    // 테이블 처리
    input = _processTables(input);

    // <br> 태그 처리
    input =
        input.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '{{br}}');

    // 다른 HTML 태그를 처리
    final document = htmlparser.parse(input);
    String processedHtml = '';

    void _processNode(dom.Node node) {
      if (node is dom.Element) {
        if (node.localName == 'table') {
          processedHtml += '{{html}}${node.outerHtml}{{/html}}';
        } else {
          processedHtml += '{{html}}${node.outerHtml}{{/html}}';
        }
        if (node.localName != 'table') {
          node.nodes.forEach(_processNode);
        }
      } else if (node is dom.Text) {
        processedHtml += node.text;
      } else {
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
      // 테이블 부분은 그대로 추가 (br 태그 보존)
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
      return '<html>$table</html>';
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
    // {{br}} 태그를 직접 처리
    if (htmlContent.trim() == '{{br}}') {
      return const TextSpan(text: '\n');
    }

    // {{html}} 태 제거
    String processedContent =
        htmlContent.replaceAll('{{html}}', '').replaceAll('{{/html}}', '');

    return WidgetSpan(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return HtmlWidget(
            processedContent,
            textStyle: TextStyle(fontSize: 16 * scaleFactor),
            customWidgetBuilder: (dom.Element element) {
              if (element.localName == 'img') {
                final String? src = element.attributes['src'];
                if (src != null) {
                  return NetworkImageWithLoader(
                    imageUrl: src,
                    fit: BoxFit.contain,
                    logger: Logger(),
                    width: constraints.maxWidth,
                  );
                }
              }
              return null;
            },
            customStylesBuilder: (element) {
              if (element.localName == 'table') {
                return {
                  'border-collapse': 'collapse',
                  'width': '100%',
                  'max-width': '${constraints.maxWidth}px',
                };
              }
              if (element.localName == 'td' || element.localName == 'th') {
                return {
                  'border': '1px solid black',
                  'padding': '10px',
                  'white-space': 'pre-wrap',
                };
              }
              return null;
            },
            onTapUrl: (url) => false,
            renderMode: RenderMode.column,
          );
        },
      ),
    );
  }
}

class DividerNode extends SpanNode {
  @override
  InlineSpan build() {
    return WidgetSpan(
      child: Row(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10.0),
              child: const Divider(color: Colors.grey, thickness: 1),
            ),
          ),
        ],
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
      : super(r'\{\{html\}\}[\s\S]*?\{\{/html\}\}|\{\{br\}\}',
            caseSensitive: false);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final htmlContent = match[0]!;
    final element = md.Element.text('html', htmlContent);
    parser.addNode(element);
    return true;
  }
}

class CustomDividerSyntax extends md.InlineSyntax {
  CustomDividerSyntax() : super(r'\{\{divider\}\}');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element('divider', []));
    return true;
  }
}

class HighlightNode extends SpanNode {
  final String text;
  final Color color;

  HighlightNode(this.text, {required this.color});

  @override
  InlineSpan build() {
    return TextSpan(
      text: text,
      style: TextStyle(
        backgroundColor: color,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class CustomHighlightSyntax extends md.InlineSyntax {
  CustomHighlightSyntax() : super(r'\{\{highlight\}\}(.*?)\{\{/highlight\}\}');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('highlight', match[1]!));
    return true;
  }
}
