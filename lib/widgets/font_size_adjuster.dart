import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:logger/logger.dart';

class FontSizeAdjuster extends StatelessWidget {
  final Logger logger;

  const FontSizeAdjuster({super.key, required this.logger});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    logger.i('Displaying Font Size Adjuster');

    return AlertDialog(
      title: const Text('글자 크기 조정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Slider(
            value: themeProvider.textScaleFactor,
            min: 0.8,
            max: 1.5,
            divisions: 7,
            label: themeProvider.textScaleFactor.toStringAsFixed(2),
            onChanged: (value) {
              themeProvider.setTextScaleFactor(value);
              logger.i('Font size adjusted to $value');
            },
          ),
          Text(
            '현재 글자 크기: ${themeProvider.textScaleFactor.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 16 * themeProvider.textScaleFactor),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            logger.i('Font Size Adjuster dialog closed');
            Navigator.of(context).pop();
          },
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
