import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/models/quiz.dart';
import 'package:provider/provider.dart';
import '../providers/review_quiz_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/quiz_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubjectReviewPage extends StatefulWidget {
  final String subjectId;

  const SubjectReviewPage({super.key, required this.subjectId});

  @override
  State<SubjectReviewPage> createState() => _SubjectReviewPageState();
}

class _SubjectReviewPageState extends State<SubjectReviewPage> {
  Set<String> _reviewedQuizIds = {};

  @override
  void initState() {
    super.initState();
    _loadReviewedQuizIds();
  }

  Future<void> _loadReviewedQuizIds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _reviewedQuizIds = prefs.getStringList('reviewedQuizIds')?.toSet() ?? {};
    });
  }

  Future<void> _saveReviewedQuizIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('reviewedQuizIds', _reviewedQuizIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ReviewQuizzesProvider, UserProvider>(
      builder: (context, provider, userProvider, child) {
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(
                  provider.getSubjectName(provider.selectedSubjectId),
                ),
                floating: true,
                snap: true,
                pinned: false,
              ),
              SliverSafeArea(
                sliver: SliverPadding(
                  padding: const EdgeInsets.all(8.0),
                  sliver: _buildQuizList(context, provider, userProvider),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuizList(BuildContext context, ReviewQuizzesProvider provider,
      UserProvider userProvider) {
    if (provider.isLoading) {
      return const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()));
    }
    if (provider.quizzesForReview.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState(context, provider));
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final quiz = provider.quizzesForReview[index];
          return ReviewPageCard(
            key: ValueKey(quiz.id),
            quiz: quiz,
            isAdmin: userProvider.isAdmin,
            questionNumber: index + 1,
            onAnswerSelected: (answerIndex) => _handleAnswerSelected(
                quiz, answerIndex, provider, userProvider),
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
            onFeedbackGiven: (quiz, isUnderstandingImproved) async {
              _reviewedQuizIds.add(quiz.id);
              await _saveReviewedQuizIds();
              setState(() {});
            }, // DONE : 복습 카드 제거를 누르면, reviewpage에서 카드가 곧바로 제거
            onRemoveCard: (quizId) {
              userProvider.removeFromReviewList(
                provider.selectedSubjectId!,
                quiz.typeId,
                quizId,
              );
              provider.removeQuizFromReview(quizId);
              _reviewedQuizIds.add(quizId);
              _saveReviewedQuizIds();
              setState(() {});
            },
          );
        },
        childCount: provider.quizzesForReview.length,
      ),
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text('잠시 후에 다시 확인해보세요!'),
        ],
      ),
    );
  }

  Future<void> _handleAnswerSelected(Quiz quiz, int answerIndex,
      ReviewQuizzesProvider provider, UserProvider userProvider) async {
    final logger = Provider.of<Logger>(context, listen: false);
    logger.i('복습 페이지 답변 선택: quizId=${quiz.id}, answerIndex=$answerIndex');
    final isCorrect = quiz.correctOptionIndex == answerIndex;

    await userProvider.updateUserQuizData(
      provider.selectedSubjectId!,
      quiz.typeId,
      quiz.id,
      isCorrect,
      selectedOptionIndex: answerIndex,
    );

    _reviewedQuizIds.add(quiz.id);
    await _saveReviewedQuizIds();
    logger.d('복습 페이지 답변 업데이트: isCorrect=$isCorrect');
    setState(() {});
  }
}
