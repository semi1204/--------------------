// quiz_type_page.dart
import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/subject_page.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/subject.dart';
import '../models/quiz_type.dart';
import 'quiz_page.dart';
import '../widgets/close_button.dart'; // CustomCloseButton import
import '../providers/user_provider.dart';
import '../widgets/linked_title.dart'; // Add this import
import '../providers/theme_provider.dart';
import '../widgets/progress_card.dart';

//  : 리스트 정렬은 23년도 기출부터 최신순으로 정렬해야 함
// 리스트에 기존에 풀었던 문제들을 산정해서, 각 tpye에 대한 진행률을 보여줘야 함
class QuizTypePage extends StatelessWidget {
  final Subject subject;

  const QuizTypePage({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final quizService = Provider.of<QuizService>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.user?.uid;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight / 1.4),
        child: AppBar(
          title: LinkedTitle(
            titles: [subject.name],
            onTap: (index) {
              if (index == 0) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const SubjectPage(),
                  ),
                );
              }
            },
          ),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          actions: const [
            CustomCloseButton(),
          ],
        ),
      ),
      body: FutureBuilder<List<QuizType>>(
        future: quizService.getQuizTypes(subject.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No quiz types available'));
          }

          final sortedQuizTypes = snapshot.data!
            ..sort((a, b) {
              int yearA = int.tryParse(a.name.split('년')[0]) ?? 0;
              int yearB = int.tryParse(b.name.split('년')[0]) ?? 0;
              return yearB.compareTo(yearA);
            });

          return ListView.builder(
            itemCount: sortedQuizTypes.length,
            itemBuilder: (context, index) {
              final quizType = sortedQuizTypes[index];
              return FutureBuilder<Map<String, dynamic>>(
                future: _calculateQuizTypeProgress(
                    quizService, userProvider, subject.id, quizType.id),
                builder: (context, progressSnapshot) {
                  if (progressSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const ListTile(title: Text('Loading...'));
                  }

                  final progressData = progressSnapshot.data ??
                      {
                        'progress': 0.0,
                        'answeredCount': 0,
                        'totalCount': 0,
                        'accuracy': 0
                      };

                  return QuizTypeCard(
                    quizType: quizType,
                    subject: subject,
                    progress: progressData['progress'] as double,
                    answeredCount: progressData['answeredCount'] as int,
                    totalCount: progressData['totalCount'] as int,
                    accuracy: progressData['accuracy'] as int,
                    userId: userId,
                    themeProvider: Provider.of<ThemeProvider>(context),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _calculateQuizTypeProgress(
      QuizService quizService,
      UserProvider userProvider,
      String subjectId,
      String quizTypeId) async {
    final quizData = userProvider.getUserQuizData();
    final subjectData = quizData[subjectId] as Map<String, dynamic>?;
    final quizTypeData = subjectData?[quizTypeId] as Map<String, dynamic>?;
    final userId = userProvider.user?.uid;

    int totalQuizzes =
        await quizService.getTotalQuizCount(subjectId, quizTypeId);
    int answeredQuizzes = quizTypeData?.values
            .where((quiz) => (quiz as Map<String, dynamic>)['total'] > 0)
            .length ??
        0;

    double progress = totalQuizzes > 0 ? answeredQuizzes / totalQuizzes : 0.0;

    int accuracy = 0;
    if (userId != null) {
      accuracy = await quizService.getWeightedAverageAccuracy(
          userId, subjectId, quizTypeId);
    }

    return {
      'progress': progress,
      'answeredCount': answeredQuizzes,
      'totalCount': totalQuizzes,
      'accuracy': accuracy
    };
  }
}

// New QuizTypeCard widget
class QuizTypeCard extends StatelessWidget {
  final QuizType quizType;
  final Subject subject;
  final double progress;
  final int answeredCount;
  final int totalCount;
  final int accuracy;
  final String? userId;
  final ThemeProvider themeProvider;

  const QuizTypeCard({
    Key? key,
    required this.quizType,
    required this.subject,
    required this.progress,
    required this.answeredCount,
    required this.totalCount,
    required this.accuracy,
    required this.userId,
    required this.themeProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProgressCard(
      title: quizType.name,
      progress: progress,
      answeredCount: answeredCount,
      totalCount: totalCount,
      accuracy: accuracy,
      userId: userId,
      themeProvider: themeProvider,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizPage(
            subject: subject,
            quizType: quizType,
          ),
        ),
      ),
    );
  }
}
