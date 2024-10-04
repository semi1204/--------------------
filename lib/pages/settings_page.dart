// settings_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../utils/constants.dart';
import '../widgets/font_size_adjuster.dart'; // Import the new widget
import 'package:logger/logger.dart'; // Ensure Logger is available

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Logger logger = Provider.of<Logger>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: getAppTextStyle(context, fontSize: 20)),
      ),
      body: Consumer2<ThemeProvider, UserProvider>(
        builder: (context, themeProvider, userProvider, child) {
          final originalReviewPeriod = 1; // 1일
          final adjustedReviewPeriod =
              (originalReviewPeriod * userProvider.reviewPeriodMultiplier)
                  .round();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Preview box for adjusted text size
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('미리보기',
                          style: getAppTextStyle(context,
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('실제 문제에서 보이는 크기',
                          style: getAppTextStyle(context,
                              fontSize: 16 * themeProvider.textScaleFactor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Replace the existing font size slider with a button to open the FontSizeAdjuster
              Text('텍스트 크기',
                  style: getAppTextStyle(context,
                      fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton(
                onPressed: () {
                  logger.i('Navigating to Font Size Adjuster from Settings');
                  showDialog(
                    context: context,
                    builder: (context) => FontSizeAdjuster(logger: logger),
                  );
                },
                child: const Text('Adjust Font Size'),
              ),
              const SizedBox(height: 24),

              // Review period information and adjustment
              Text('복습 주기',
                  style: getAppTextStyle(context,
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                '사용자 복습 주기: ${_formatDuration(Duration(days: adjustedReviewPeriod))}',
                style: getAppTextStyle(context, fontSize: 14),
              ),
              Text(
                '기본 복습 주기: 1 day',
                style: getAppTextStyle(context, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Slider(
                value: userProvider.reviewPeriodMultiplier,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                label: userProvider.reviewPeriodMultiplier.toStringAsFixed(2),
                onChanged: (value) =>
                    userProvider.setReviewPeriodMultiplier(value),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} ${duration.inDays == 1 ? 'day' : 'days'} later';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} ${duration.inHours == 1 ? 'hour' : 'hours'} later';
    } else {
      return '${duration.inMinutes} ${duration.inMinutes == 1 ? 'minute' : 'minutes'} later';
    }
  }
}
