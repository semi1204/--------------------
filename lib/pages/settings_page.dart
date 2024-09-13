// settings_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';
import '../utils/constants.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                      Text('Preview',
                          style: getAppTextStyle(context,
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('This is how your text will look.',
                          style: getAppTextStyle(context,
                              fontSize: 16 * themeProvider.textScaleFactor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Text size adjustment
              Text('Text Size',
                  style: getAppTextStyle(context,
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Slider(
                value: themeProvider.textScaleFactor,
                min: 0.8,
                max: 1.5,
                divisions: 7,
                label: themeProvider.textScaleFactor.toStringAsFixed(2),
                onChanged: (value) => themeProvider.setTextScaleFactor(value),
              ),
              const SizedBox(height: 24),

              // Review period information and adjustment
              Text('Review Period',
                  style: getAppTextStyle(context,
                      fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                'Next review: ${_formatDuration(Duration(days: adjustedReviewPeriod))}',
                style: getAppTextStyle(context, fontSize: 14),
              ),
              Text(
                'Original review period: 1 day',
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
