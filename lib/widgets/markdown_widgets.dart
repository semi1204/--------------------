// lib/widgets/markdown_widgets.dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:logger/logger.dart';
import 'common_widgets.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class MarkdownRenderer extends StatelessWidget {
  final String data;
  final Logger logger;

  const MarkdownRenderer({Key? key, required this.data, required this.logger})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: true,
      builders: {
        'math': MathBuilder(logger: logger),
        'img': ImageBuilder(logger: logger),
      },
      extensionSet: md.ExtensionSet([
        const md.TableSyntax(),
      ], [
        ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        InlineMathSyntax(),
        // BlockMathSyntax는 여기서 제거합니다.
      ]),
    );
  }
}

class MathBuilder extends MarkdownElementBuilder {
  final Logger logger;

  MathBuilder({required this.logger});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag == 'math') {
      logger.d('Rendering math: ${element.textContent}');
      return Math.tex(
        element.textContent,
        mathStyle: MathStyle.display,
        textStyle: preferredStyle,
      );
    }
    return null;
  }
}

class ImageBuilder extends MarkdownElementBuilder {
  final Logger logger;

  ImageBuilder({required this.logger});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag == 'img') {
      final src = element.attributes['src'];
      if (src != null) {
        logger.d('Rendering image: $src');
        return NetworkImageWithLoader(imageUrl: src);
      }
    }
    return null;
  }
}

// 추가: 기존 markdown_field.dart에서 가져온 구문 분석기 클래스들
class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(r'\$([^$\n]+)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('math', match[1]!));
    return true;
  }
}

class KoreanFractionSyntax extends md.InlineSyntax {
  KoreanFractionSyntax()
      : super(r'\{([\p{Hangul}\s]+)\s*/\s*([\p{Hangul}\s]+)\}');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('math', '\\frac{${match[1]}}{${match[2]}}');
    parser.addNode(element);
    return true;
  }
}
