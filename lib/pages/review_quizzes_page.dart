import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/providers/review_quiz_provider.dart';
import 'package:nursing_quiz_app_6/widgets/add_quiz/subject_dropdown_with_add_button.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
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
    final provider = Provider.of<ReviewQuizzesProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    if (provider.selectedSubjectId == null && initialSubjectId != null) {
      provider.setSelectedSubjectId(initialSubjectId);
      provider.loadQuizzesForReview();
    }

    return Scaffold(
      body: Column(
        children: [
          UnifiedSubjectDropdown(
            selectedSubjectId: provider.selectedSubjectId,
            onSubjectSelected: (String? newSubjectId) {
              provider.setSelectedSubjectId(newSubjectId);
              if (newSubjectId != null) {
                provider.loadQuizzesForReview();
              }
            },
          ),
          Expanded(
            child: _buildQuizList(context, provider, userProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizList(BuildContext context, ReviewQuizzesProvider provider,
      UserProvider userProvider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.isAllQuizzesCompleted) {
      return _buildEmptyState(context, provider);
    }
    return ListView.builder(
      itemCount: provider.quizzesForReview.length,
      itemBuilder: (context, index) {
        final quiz = provider.quizzesForReview[index];
        if (provider.completedQuizIds.contains(quiz.id)) {
          return const SizedBox.shrink();
        }
        return ReviewPageCard(
          key: ValueKey(quiz.id),
          quiz: quiz,
          isAdmin: userProvider.isAdmin,
          questionNumber: index + 1,
          onAnswerSelected: (answerIndex) =>
              _handleAnswerSelected(quiz, answerIndex, provider, userProvider),
          subjectId: provider.selectedSubjectId!,
          quizTypeId: quiz.typeId,
          nextReviewDate: userProvider
                  .getNextReviewDate(
                    provider.selectedSubjectId!,
                    quiz.typeId,
                    quiz.id,
                  )
                  ?.toIso8601String() ??
              DateTime.now().toIso8601String(),
          onFeedbackGiven: (quiz, isUnderstandingImproved) {
            provider.addCompletedQuizId(quiz.id);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(
      BuildContext context, ReviewQuizzesProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.celebration,
              size: 80, color: Color.fromARGB(255, 255, 153, 0)),
          const SizedBox(height: 20),
          Text(
              '${provider.getSubjectName(provider.selectedSubjectId)}의 모든 퀴즈를 완료했어요! 🎉',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('잠시 후에 다시 확인해보세요!'),
        ],
      ),
    );
  }

  Future<void> _handleAnswerSelected(Quiz quiz, int answerIndex,
      ReviewQuizzesProvider provider, UserProvider userProvider) async {
    final logger = Provider.of<Logger>(provider as BuildContext, listen: false);
    logger.i('복습 페이지 답변 선택: quizId=${quiz.id}, answerIndex=$answerIndex');
    final isCorrect = quiz.correctOptionIndex == answerIndex;

    await userProvider.updateUserQuizData(
      provider.selectedSubjectId!,
      quiz.typeId,
      quiz.id,
      isCorrect,
      selectedOptionIndex: answerIndex,
    );

    provider.addCompletedQuizId(quiz.id);

    logger.d('복습 페이지 답변 업데이트: isCorrect=$isCorrect');
  }
}
