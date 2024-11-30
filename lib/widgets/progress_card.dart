import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';
import '../pages/subject_page.dart';

class ProgressCard extends StatelessWidget {
  final String title;
  final double progress;
  final int answeredCount;
  final int totalCount;
  final int accuracy;
  final String? userId;
  final ThemeProvider themeProvider;
  final VoidCallback onTap;

  const ProgressCard({
    Key? key,
    required this.title,
    required this.progress,
    required this.answeredCount,
    required this.totalCount,
    required this.accuracy,
    required this.userId,
    required this.themeProvider,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode
              ? ThemeProvider.darkModeSurface
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: ThemeProvider.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: ThemeProvider.primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: ThemeProvider.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ProgressSection(
                          progress: progress,
                          answeredCount: answeredCount,
                          totalCount: totalCount,
                          themeProvider: themeProvider,
                        ),
                      ),
                      if (userId != null) ...[
                        const SizedBox(width: 32),
                        Expanded(
                          child: AccuracySection(
                            accuracy: accuracy,
                            themeProvider: themeProvider,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
