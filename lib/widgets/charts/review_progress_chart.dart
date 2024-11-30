import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:nursing_quiz_app_6/providers/review_quiz_provider.dart';
import 'package:nursing_quiz_app_6/providers/theme_provider.dart'; // 추가

class ReviewProgressChart extends StatelessWidget {
  const ReviewProgressChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReviewQuizzesProvider>(
      builder: (context, provider, child) {
        if (provider.selectedSubjectId == null) {
          return const Center(child: Text('과목을 선택해주세요.'));
        }

        return FutureBuilder<Map<String, int>>(
          future: provider.getReviewProgress(provider.selectedSubjectId!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            final total = data['total'] ?? 0;
            final completed = data['completed'] ?? 0;
            final remaining = data['remaining'] ?? 0;
            final delayed = data['delayed'] ?? 0;

            if (total == 0) {
              return const Center(child: Text('오늘 복습할 문제가 없습니다.'));
            }

            return Column(
              children: [
                Text('오늘의 복습 진행률'),
                SizedBox(height: 20),
                _buildProgressChart(completed, remaining, delayed),
                SizedBox(height: 20),
                _buildLegend(context, completed, remaining, delayed),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProgressChart(int completed, int remaining, int delayed) {
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              value: completed.toDouble(),
              color: Colors.blue,
              title: '',
              radius: 50,
            ),
            PieChartSectionData(
              value: remaining.toDouble(),
              color: Colors.grey.shade300,
              title: '',
              radius: 45,
            ),
            if (delayed > 0)
              PieChartSectionData(
                value: delayed.toDouble(),
                color: Colors.red.shade300,
                title: '',
                radius: 45,
              ),
          ],
          sectionsSpace: 0,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }

  Widget _buildLegend(
    BuildContext context,
    int completed,
    int remaining,
    int delayed,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(context, '완료', completed, Colors.blue),
        const SizedBox(width: 16),
        _buildLegendItem(context, '남음', remaining, Colors.grey.shade300),
        if (delayed > 0) ...[
          const SizedBox(width: 16),
          _buildLegendItem(context, '지연', delayed, Colors.red.shade300),
        ],
      ],
    );
  }

  Widget _buildLegendItem(
    BuildContext context,
    String label,
    int value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label($value)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
