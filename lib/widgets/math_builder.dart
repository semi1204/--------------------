// lib/widgets/math_builder.dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:logger/logger.dart';

class MathBuilder extends MarkdownElementBuilder {
  final Logger logger;

  MathBuilder({required this.logger});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag == 'math') {
      logger.d('Rendering math: ${element.textContent}');
      return Math.tex(
        _processKoreanInLatex(element.textContent),
        mathStyle: MathStyle.display,
        textStyle: preferredStyle,
      );
    }
    return null;
  }

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    final String textContent = text.text;
    logger.d('Rendering text: $textContent');
    try {
      // Handle inline math
      if (textContent.startsWith(r'$') && textContent.endsWith(r'$')) {
        return Math.tex(
          _processKoreanInLatex(
              textContent.substring(1, textContent.length - 1)),
          mathStyle: MathStyle.text,
          textStyle: preferredStyle,
        );
      }
      // Handle Korean fractions
      else if (textContent.contains('/') &&
          RegExp(r'[\p{Script=Hangul}]', unicode: true).hasMatch(textContent)) {
        return _buildKoreanFraction(textContent, preferredStyle);
      }
    } catch (e) {
      logger.e('Error rendering math: $e');
    }
    return null;
  }

  String _processKoreanInLatex(String text) {
    return text.replaceAllMapped(
      RegExp(r'([\p{Script=Hangul}]+)', unicode: true),
      (match) => '\\text{${match.group(1)}}',
    );
  }

  Widget _buildKoreanFraction(String text, TextStyle? preferredStyle) {
    final parts = text.split('/');
    if (parts.length == 2) {
      return Math.tex(
        '\\frac{${_processKoreanInLatex(parts[0].trim())}}{${_processKoreanInLatex(parts[1].trim())}}',
        mathStyle: MathStyle.text,
        textStyle: preferredStyle,
      );
    }
    return Text(text, style: preferredStyle);
  }
}
