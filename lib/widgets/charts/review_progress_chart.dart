import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:nursing_quiz_app_6/providers/review_quiz_provider.dart';
import 'package:nursing_quiz_app_6/providers/theme_provider.dart'; // 추가

class ReviewProgressChart extends StatelessWidget {
  const ReviewProgressChart({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Use Consumer to listen to ReviewQuizzesProvider changes
    return Consumer<ReviewQuizzesProvider>(
      builder: (context, provider, child) {
        if (provider.selectedSubjectId == null) {
          return Center(
            child: Text(
              '과목을 선택해주세요.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: themeProvider.textColor,
                  ),
            ),
          );
        }

        return FutureBuilder<Map<String, int>>(
          future: provider.getReviewProgress(provider.selectedSubjectId!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final currentTotalQuizzes = snapshot.data!['total'] ?? 0;
            final completedQuizzes = snapshot.data!['completed'] ?? 0;

            final double progress = currentTotalQuizzes > 0
                ? completedQuizzes / currentTotalQuizzes
                : 0;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
                vertical: MediaQuery.of(context).size.height * 0.02,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '오늘의 복습 진행률',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: themeProvider.textColor,
                        ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.2,
                        child: PieChart(
                          PieChartData(
                            sections: _buildChartSections(
                                completedQuizzes, currentTotalQuizzes),
                            sectionsSpace: 0,
                            centerSpaceRadius:
                                MediaQuery.of(context).size.width * 0.1,
                            startDegreeOffset: -90,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(progress * 100).toStringAsFixed(1)}%',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                          ),
                          SizedBox(
                              height:
                                  MediaQuery.of(context).size.height * 0.01),
                          Text(
                            '$completedQuizzes / $currentTotalQuizzes',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: themeProvider.textColor,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                  _buildLegend(context),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<PieChartSectionData> _buildChartSections(int completed, int total) {
    return [
      PieChartSectionData(
        color: Colors.blue,
        value: completed.toDouble(),
        title: '',
        radius: 50,
        showTitle: false,
      ),
      PieChartSectionData(
        color: Colors.grey.shade300,
        value: (total - completed).toDouble(),
        title: '',
        radius: 45,
        showTitle: false,
      ),
    ];
  }

  Widget _buildLegend(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem(context, '완료한 문제', Colors.blue),
        _buildLegendItem(context, '남은 문제', Colors.grey.shade300),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: themeProvider.textColor,
              ),
        ),
      ],
    );
  }
}
