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

    Color accuracyColor;
    if (accuracy >= 0.85) {
      accuracyColor = Colors.green;
    } else if (accuracy >= 0.60) {
      accuracyColor = Colors.yellow;
    } else {
      accuracyColor = Colors.red;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accuracyColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart,
            size: 16,
            color: accuracyColor,
          ),
          const SizedBox(width: 6),
          Text(
            '$accuracyPercentage%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
