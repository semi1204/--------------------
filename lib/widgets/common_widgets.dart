// lib/widgets/common_widgets.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:logger/logger.dart';

class NetworkImageWithLoader extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;

  const NetworkImageWithLoader({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final logger = Logger();
    logger.d('Building NetworkImageWithLoader: $imageUrl');
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      placeholder: (context, url) => const CircularProgressIndicator(),
      errorWidget: (context, url, error) {
        logger.e('Error loading image: $error');
        return const Icon(Icons.error);
      },
    );
  }
}

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
