import 'package:flutter/material.dart';

class AccuracyDisplay extends StatelessWidget {
  final int correctAttempts;
  final int totalAttempts;

  const AccuracyDisplay({
    Key? key,
    required this.correctAttempts,
    required this.totalAttempts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final accuracy = totalAttempts > 0
        ? (correctAttempts / totalAttempts * 100).toStringAsFixed(1)
        : '0.0';

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
            '$accuracy%',
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
