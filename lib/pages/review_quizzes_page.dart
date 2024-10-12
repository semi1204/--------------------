import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/subjects_review_page.dart';
import 'package:nursing_quiz_app_6/providers/review_quiz_provider.dart';
import 'package:nursing_quiz_app_6/services/payment_service.dart';
import 'package:nursing_quiz_app_6/widgets/add_quiz/subject_dropdown_with_add_button.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../providers/user_provider.dart';
import 'package:logger/logger.dart';
import '../widgets/charts/review_progress_chart.dart';
import '../widgets/review_period_settings_dialog.dart';
import 'package:nursing_quiz_app_6/pages/login_page.dart'; // Add this import

class ReviewQuizzesPage extends StatelessWidget {
  final String? initialSubjectId;
  final String? initialQuizId;

  const ReviewQuizzesPage({
    super.key,
    this.initialSubjectId,
    this.initialQuizId,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ReviewQuizzesProvider(
        Provider.of<QuizService>(context, listen: false),
        Provider.of<Logger>(context, listen: false),
        Provider.of<UserProvider>(context, listen: false).user?.uid,
      )..loadSubjects(),
      child: _ReviewQuizzesPageContent(
        initialSubjectId: initialSubjectId,
        initialQuizId: initialQuizId,
      ),
    );
  }
}

class _ReviewQuizzesPageContent extends StatefulWidget {
  final String? initialSubjectId;
  final String? initialQuizId;

  const _ReviewQuizzesPageContent({
    super.key,
    this.initialSubjectId,
    this.initialQuizId,
  });

  @override
  _ReviewQuizzesPageContentState createState() =>
      _ReviewQuizzesPageContentState();
}

class _ReviewQuizzesPageContentState extends State<_ReviewQuizzesPageContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<ReviewQuizzesProvider>(context, listen: false);
      if (widget.initialSubjectId != null) {
        provider.setSelectedSubjectId(widget.initialSubjectId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReviewQuizzesProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Row(
                    children: [
                      Expanded(
                        child: UnifiedSubjectDropdown(
                          selectedSubjectId: provider.selectedSubjectId,
                          onSubjectSelected: (String? newSubjectId) {
                            if (newSubjectId != null) {
                              provider.setSelectedSubjectId(newSubjectId);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () =>
                            _showReviewPeriodSettingsDialog(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 60),
              if (provider.selectedSubjectId != null) ...[
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: const ReviewProgressChart(),
                ),
                const SizedBox(height: 40),
                FilledButton(
                  onPressed: () {
                    final userProvider =
                        Provider.of<UserProvider>(context, listen: false);
                    if (userProvider.user == null) {
                      _showLoginPrompt(context);
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider<
                              ReviewQuizzesProvider>.value(
                            value: provider,
                            child: SubjectReviewPage(
                                subjectId: provider.selectedSubjectId!),
                          ),
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow),
                      SizedBox(width: 8),
                      Text(
                        '복습 시작하기',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ] else
                const Text(
                  '과목을 선택하세요! \n오늘의 복습문제를 확인할 수 있어요',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        );
      },
    );
  }

  void _showReviewPeriodSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const ReviewPeriodSettingsDialog();
      },
    );
  }

  void _showLoginPrompt(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('로그인이 필요합니다.'),
        action: SnackBarAction(
          label: '로그인',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
        ),
      ),
    );
  }

  void _showSubscriptionPrompt(BuildContext context) {
    final paymentService = Provider.of<PaymentService>(context, listen: false);
    paymentService.showSubscriptionDialog(context);
  }
}
