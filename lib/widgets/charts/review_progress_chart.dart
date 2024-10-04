import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ReviewProgressChart extends StatelessWidget {
  final int initialTotalQuizzes;
  final int totalQuizzes;
  final int completedQuizzes;

  const ReviewProgressChart({
    super.key,
    required this.initialTotalQuizzes,
    required this.totalQuizzes,
    required this.completedQuizzes,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = initialTotalQuizzes > 0
        ? completedQuizzes / initialTotalQuizzes
        : 0; // 복습 진행률은 초기 문제 수를 기준으로 계산

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('오늘의 복습 진행률: ${(progress * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 20),
        SizedBox(
          height: 150,
          child: PieChart(
            PieChartData(
              sections: _buildChartSections(),
              sectionsSpace: 0,
              centerSpaceRadius: 25,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('완료한 복습: $completedQuizzes / $initialTotalQuizzes'),
      ],
    );
  }

  List<PieChartSectionData> _buildChartSections() {
    return [
      PieChartSectionData(
        color: Colors.blue,
        value: completedQuizzes.toDouble(),
        title: '완료한 문제',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: Colors.grey,
        value: (initialTotalQuizzes - completedQuizzes).toDouble(),
        title: '남은 문제',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }
}
