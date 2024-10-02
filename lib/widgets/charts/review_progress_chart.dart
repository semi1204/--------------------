import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ReviewProgressChart extends StatelessWidget {
  final int totalQuizzes;
  final int completedQuizzes;

  const ReviewProgressChart({
    super.key,
    required this.totalQuizzes,
    required this.completedQuizzes,
  });

  @override
  Widget build(BuildContext context) {
    final double progress =
        totalQuizzes > 0 ? completedQuizzes / totalQuizzes : 0;

    // SingleChildScrollView 제거
    return Column(
      mainAxisSize: MainAxisSize.min, // Column의 크기를 내용에 맞게 조정
      children: [
        Text('오늘의 복습 진행률: ${(progress * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 20),
        // PieChart 크기 조정
        SizedBox(
          height: 150, // 고정 높이 설정
          child: PieChart(
            PieChartData(
              sections: [
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
                  value: (totalQuizzes - completedQuizzes).toDouble(),
                  title: '남은 문제',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
              sectionsSpace: 0,
              centerSpaceRadius: 25,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('완료한 복습: $completedQuizzes / $totalQuizzes'),
      ],
    );
  }
}
