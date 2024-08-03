// accuracy_display.dart

import 'package:flutter/material.dart';

class AccuracyDisplay extends StatelessWidget {
  final double accuracy;

  const AccuracyDisplay({
    super.key,
    required this.accuracy,
  });

  @override
  Widget build(BuildContext context) {
    final accuracyPercentage = (accuracy * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart, size: 16, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            '$accuracyPercentage%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
