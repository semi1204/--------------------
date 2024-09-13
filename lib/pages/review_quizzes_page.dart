import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/subjects_review_page.dart';
import 'package:nursing_quiz_app_6/providers/review_quiz_provider.dart';
import 'package:nursing_quiz_app_6/widgets/add_quiz/subject_dropdown_with_add_button.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../providers/user_provider.dart';
import 'package:logger/logger.dart';

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

class _ReviewQuizzesPageContent extends StatelessWidget {
  final String? initialSubjectId;
  final String? initialQuizId;

  const _ReviewQuizzesPageContent({
    super.key,
    this.initialSubjectId,
    this.initialQuizId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ReviewQuizzesProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            const SizedBox(height: 20), // 상단 여백 추가
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8, // 화면 너비의 80%
                child: UnifiedSubjectDropdown(
                  selectedSubjectId: provider.selectedSubjectId,
                  onSubjectSelected: (String? newSubjectId) {
                    if (newSubjectId != null) {
                      provider.setSelectedSubjectId(newSubjectId);
                      provider.loadQuizzesForReview().then((_) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider<
                                ReviewQuizzesProvider>.value(
                              value: provider,
                              child: SubjectReviewPage(subjectId: newSubjectId),
                            ),
                          ),
                        );
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 10), // 간격 추가
            const Text(
              '과목을 선택하세요! \n오늘의 복습문제를 확인할 수 있어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      },
    );
  }
}
