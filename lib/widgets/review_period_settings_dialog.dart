import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/user_provider.dart';

class ReviewPeriodSettingsDialog extends StatefulWidget {
  const ReviewPeriodSettingsDialog({super.key});

  @override
  State<ReviewPeriodSettingsDialog> createState() =>
      _ReviewPeriodSettingsDialogState();
}

class _ReviewPeriodSettingsDialogState
    extends State<ReviewPeriodSettingsDialog> {
  late double _reviewPeriodMultiplier;

  @override
  void initState() {
    super.initState();
    _reviewPeriodMultiplier = Provider.of<UserProvider>(context, listen: false)
        .reviewPeriodMultiplier;
  }

  List<FlSpot> _generateReviewPoints(double multiplier) {
    List<int> reviewDays = [1, 3, 7, 15];
    return reviewDays.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value * multiplier);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('복습 주기 설정'),
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
                        color: Colors.grey[300],
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
                                style: const TextStyle(
                                  color: Color(0xff68737d),
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
                            style: const TextStyle(
                              color: Color(0xff68737d),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.right,
                          );
                        },
                      ),
                    ),
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border:
                        Border.all(color: const Color(0xff37434d), width: 1),
                  ),
                  minX: 0,
                  maxX: 3,
                  minY: 0,
                  maxY: 30,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _generateReviewPoints(_reviewPeriodMultiplier),
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
                            strokeColor: Color(0xff02d39a),
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
              value: _reviewPeriodMultiplier,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: _reviewPeriodMultiplier.toStringAsFixed(2),
              onChanged: (value) {
                setState(() {
                  _reviewPeriodMultiplier = value;
                });
              },
            ),
            Text(
              '복습 주기 배수: ${_reviewPeriodMultiplier.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('취소'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('저장'),
          onPressed: () {
            Provider.of<UserProvider>(context, listen: false)
                .setReviewPeriodMultiplier(_reviewPeriodMultiplier);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
