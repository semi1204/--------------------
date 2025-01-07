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
                  onPressed: () => _handleReviewStart(context, provider),
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

  // 구독 상태 확인 후 구독 다이얼로그 표시
  void _showSubscriptionPrompt(BuildContext context) async {
    final paymentService = Provider.of<PaymentService>(context, listen: false);
    // 구독 상태 확인
    final isSubscribed = await paymentService.checkSubscriptionStatus();

    // 구독 상태가 아니면 구독 다이얼로그 표시
    if (!isSubscribed && mounted) {
      paymentService.showEnhancedSubscriptionDialog(context);
    }
  }

  void _handleReviewStart(
      BuildContext context, ReviewQuizzesProvider provider) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final logger = Provider.of<Logger>(context, listen: false);
    // 1. 로그인 여부 확인
    if (userProvider.user == null) {
      _showLoginPrompt(context);
      return;
    }

    logger.d('Checking access for user: ${userProvider.user?.email}');

    // 2. 구독 상태 확인
    final paymentService = Provider.of<PaymentService>(context, listen: false);
    final hasAccess = await paymentService.checkSubscriptionStatus();

    logger.d('Access check result: $hasAccess');

    // 3. 구독 상태가 아니면 구독 다이얼로그 표시
    if (!hasAccess) {
      if (!mounted) return;
      _showSubscriptionPrompt(context);
      return;
    }

    // 4. 구독 상태가 맞으면 복습 페이지로 이동
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<ReviewQuizzesProvider>.value(
          value: provider,
          child: SubjectReviewPage(subjectId: provider.selectedSubjectId!),
        ),
      ),
    );
  }
}
