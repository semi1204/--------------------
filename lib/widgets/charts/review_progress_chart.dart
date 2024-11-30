import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:nursing_quiz_app_6/providers/review_quiz_provider.dart';
import 'package:nursing_quiz_app_6/providers/theme_provider.dart';

class ReviewProgressChart extends StatelessWidget {
  const ReviewProgressChart({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Consumer<ReviewQuizzesProvider>(
      builder: (context, provider, child) {
        if (provider.selectedSubjectId == null) {
          return Center(
            child: Text(
              '과목을 선택해주세요.',
              style: TextStyle(
                color: themeProvider.textColor,
                fontSize: 16,
              ),
            ),
          );
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

            if (total == 0) {
              return Center(
                child: Text(
                  '오늘 복습할 문제가 없습니다.',
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 16,
                  ),
                ),
              );
            }

            return Column(
              children: [
                Text(
                  '오늘의 복습 진행률',
                  style: TextStyle(
                    color: themeProvider.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                _buildProgressChart(completed, remaining, themeProvider),
                const SizedBox(height: 30),
                _buildLegend(context, completed, remaining, themeProvider),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProgressChart(
      int completed, int remaining, ThemeProvider themeProvider) {
    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              value: completed.toDouble(),
              color: ThemeProvider.primaryColor,
              title:
                  '${((completed / (completed + remaining)) * 100).toInt()}%',
              titleStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
              ),
              radius: 60,
            ),
            PieChartSectionData(
              value: remaining.toDouble(),
              color: themeProvider.isDarkMode
                  ? Colors.grey.shade700
                  : Colors.grey.shade300,
              title: '',
              radius: 55,
            ),
          ],
          sectionsSpace: 2,
          centerSpaceRadius: 50,
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildLegend(
    BuildContext context,
    int completed,
    int remaining,
    ThemeProvider themeProvider,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(context, '완료', completed, ThemeProvider.primaryColor,
            themeProvider),
        const SizedBox(width: 24),
        _buildLegendItem(
            context,
            '남음',
            remaining,
            themeProvider.isDarkMode
                ? Colors.grey.shade700
                : Colors.grey.shade300,
            themeProvider),
      ],
    );
  }

  Widget _buildLegendItem(
    BuildContext context,
    String label,
    int value,
    Color color,
    ThemeProvider themeProvider,
  ) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: themeProvider.isDarkMode ? Colors.white54 : Colors.black54,
              width: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label($value)',
          style: TextStyle(
            color: themeProvider.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
