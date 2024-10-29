import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'markdown_field.dart'; // Add this import

class OptionFields extends StatelessWidget {
  final List<TextEditingController> controllers;
  final int correctOptionIndex;
  final Function(int?) onOptionChanged;
  final Logger logger;
  final bool isOX;

  const OptionFields({
    super.key,
    required this.controllers,
    required this.correctOptionIndex,
    required this.onOptionChanged,
    required this.logger,
    required this.isOX,
  });

  @override
  Widget build(BuildContext context) {
    logger.i('옵션 필드 빌드: ${isOX ? 'OX' : '일반'} 퀴즈');
    return isOX ? _buildOXOptions() : _buildRegularOptions();
  }

  Widget _buildOXOptions() {
    return Row(
      children: List.generate(controllers.length, (index) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: RadioListTile<int>(
              title: Text(controllers[index].text),
              value: index,
              groupValue: correctOptionIndex,
              onChanged: (int? value) {
                if (value != null && value != correctOptionIndex) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onOptionChanged(value);
                    logger.i('Correct option changed to: ${value + 1}');
                  });
                }
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRegularOptions() {
    return Column(
      children: List.generate(controllers.length, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: RadioListTile<int>(
            title: MarkdownField(
              controller: controllers[index],
              labelText: 'Option ${index + 1}',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  logger.w('Option ${index + 1} is empty');
                  return '옵션을 입력해주세요';
                }
                return null;
              },
              isPreviewMode: false,
              logger: logger,
            ),
            value: index,
            groupValue: correctOptionIndex,
            onChanged: (int? value) {
              if (value != null && value != correctOptionIndex) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onOptionChanged(value);
                  logger.i('Correct option changed to: ${value + 1}');
                });
              }
            },
          ),
        );
      }),
    );
  }
}
