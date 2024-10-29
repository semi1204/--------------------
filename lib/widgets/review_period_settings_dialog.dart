import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/utils/anki_algorithm.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/user_provider.dart';
import '../providers/theme_provider.dart'; // 추가

class ReviewPeriodSettingsDialog extends StatefulWidget {
  const ReviewPeriodSettingsDialog({super.key});

  @override
  State<ReviewPeriodSettingsDialog> createState() =>
      _ReviewPeriodSettingsDialogState();
}

class _ReviewPeriodSettingsDialogState
    extends State<ReviewPeriodSettingsDialog> {
  late double _targetRetention;

  @override
  void initState() {
    super.initState();
    _targetRetention =
        Provider.of<UserProvider>(context, listen: false).targetRetention;
  }

  List<FlSpot> _generateReviewPoints(double retention) {
    List<int> reviewDays = [1, 3, 7, 15];
    return reviewDays.asMap().entries.map((entry) {
      // AnkiAlgorithm의 로직을 직접 사용하는 것이 더 일관성 있을 수 있음
      double interval = AnkiAlgorithm.calculateIntervalForRetention(
          entry.value.toDouble(), retention);
      return FlSpot(entry.key.toDouble(), interval);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return AlertDialog(
      backgroundColor: themeProvider.currentTheme.dialogBackgroundColor,
      title: Text('목표 기억 유지율 설정',
          style: TextStyle(color: themeProvider.textColor)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 300,
              width: 350,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: themeProvider.isDarkMode
                            ? Colors.grey[700]
                            : Colors.grey[300],
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          List<int> reviewDays = [1, 3, 7, 15];
                          int index = value.toInt();
                          if (index >= 0 && index < reviewDays.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '${index + 1}회차',
                                style: TextStyle(
                                  color: themeProvider.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}일',
                            style: TextStyle(
                              color: themeProvider.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.right,
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border:
                        Border.all(color: themeProvider.textColor, width: 1),
                  ),
                  minX: 0,
                  maxX: 3,
                  minY: 0,
                  maxY: 30,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _generateReviewPoints(_targetRetention),
                      isCurved: true,
                      curveSmoothness: 0.35,
                      gradient: const LinearGradient(
                        colors: [Color(0xff23b6e6), Color(0xff02d39a)],
                      ),
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 6,
                            color: Colors.white,
                            strokeWidth: 4,
                            strokeColor: const Color(0xff02d39a),
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xff23b6e6).withOpacity(0.1),
                            const Color(0xff02d39a).withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Slider(
              value: _targetRetention,
              min: 0.6,
              max: 0.95,
              divisions: 25,
              label: '${(_targetRetention * 100).toStringAsFixed(1)}%',
              onChanged: (value) {
                setState(() {
                  _targetRetention = value;
                });
              },
            ),
            Text(
              '목표 기억 유지율: ${(_targetRetention * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text('취소', style: TextStyle(color: themeProvider.textColor)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text('저장', style: TextStyle(color: themeProvider.textColor)),
          onPressed: () {
            Provider.of<UserProvider>(context, listen: false)
                .setTargetRetention(_targetRetention);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
