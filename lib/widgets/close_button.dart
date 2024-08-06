import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class CloseButton extends StatelessWidget {
  const CloseButton({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = Provider.of<Logger>(context, listen: false);

    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: () {
        logger.i('Close button pressed');
        Navigator.of(context).popUntil((route) => route.settings.name == '/');
      },
    );
  }
}
