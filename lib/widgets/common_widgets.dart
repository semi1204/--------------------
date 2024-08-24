// lib/widgets/common_widgets.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onConfirm;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final logger = Logger();
    logger.d('Building ConfirmationDialog: $title');
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            logger.d('ConfirmationDialog: Cancel pressed');
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Confirm'),
          onPressed: () {
            logger.d('ConfirmationDialog: Confirm pressed');
            onConfirm();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class InfoDialog extends StatelessWidget {
  final String title;
  final String content;

  const InfoDialog({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Text(
          content,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('알겠어요! 👍'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class CommonSnackBar extends SnackBar {
  CommonSnackBar({
    super.key,
    required String message,
    Color backgroundColor = const Color.fromARGB(255, 106, 105, 106),
    Duration duration = const Duration(seconds: 1),
  }) : super(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: backgroundColor,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        );
}
