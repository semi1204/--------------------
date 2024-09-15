// quiz_type_page.dart
import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/subject_page.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/subject.dart';
import '../models/quiz_type.dart';
import 'quiz_page.dart';
import 'package:logger/logger.dart';
import '../widgets/close_button.dart'; // CustomCloseButton import
import '../providers/user_provider.dart';
import '../widgets/linked_title.dart'; // Add this import

//  : 리스트 정렬은 23년도 기출부터 최신순으로 정렬해야 함
// 리스트에 기존에 풀었던 문제들을 산정해서, 각 tpye에 대한 진행률을 보여줘야 함
class QuizTypePage extends StatelessWidget {
  final Subject subject;

  const QuizTypePage({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final quizService = Provider.of<QuizService>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final logger = Provider.of<Logger>(context, listen: false);

    logger.i('Building QuizTypePage for subject: ${subject.name}');

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
            logger.i('Waiting for quiz types data');
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            logger.w('No quiz types available for subject: ${subject.name}');
            return const Center(child: Text('No quiz types available'));
          }
          logger.i(
              'Quiz types loaded successfully. Count: ${snapshot.data!.length}');
          // 퀴즈 타입을 연도 기준으로 내림차순 정렬 (최신순)
          final sortedQuizTypes = snapshot.data!
            ..sort((a, b) {
              // 연도 추출 (예: "23년도" -> 23)
              int yearA = int.tryParse(a.name.split('년')[0]) ?? 0;
              int yearB = int.tryParse(b.name.split('년')[0]) ?? 0;
              return yearB.compareTo(yearA);
            });

          return ListView.builder(
            itemCount: sortedQuizTypes.length,
            itemBuilder: (context, index) {
              final quizType = sortedQuizTypes[index];
              return FutureBuilder<Map<String, dynamic>>(
                future: _calculateProgress(
                    quizService, userProvider, subject.id, quizType.id),
                builder: (context, progressSnapshot) {
                  if (progressSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const ListTile(title: Text('Loading...'));
                  }
                  final progressData = progressSnapshot.data ??
                      {'progress': 0.0, 'answeredCount': 0, 'totalCount': 0};
                  final progress = progressData['progress'] as double;
                  final answeredCount = progressData['answeredCount'] as int;
                  final totalCount = progressData['totalCount'] as int;

                  return Card(
                    elevation: 0.5,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      title: Text(
                        quizType.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[300],
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                          const SizedBox(height: 4),
                          Text('$answeredCount / $totalCount 완료',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: Text('${(progress * 100).toStringAsFixed(1)}%'),
                      onTap: () {
                        logger.i('User tapped on quiz type: ${quizType.name}');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuizPage(
                              subject: subject,
                              quizType: quizType,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _calculateProgress(QuizService quizService,
      UserProvider userProvider, String subjectId, String quizTypeId) async {
    final quizData = userProvider.getUserQuizData();
    final subjectData = quizData[subjectId] as Map<String, dynamic>?;
    if (subjectData == null)
      return {'progress': 0.0, 'answeredCount': 0, 'totalCount': 0};

    final quizTypeData = subjectData[quizTypeId] as Map<String, dynamic>?;
    if (quizTypeData == null)
      return {'progress': 0.0, 'answeredCount': 0, 'totalCount': 0};

    int totalQuizzes =
        await quizService.getTotalQuizCount(subjectId, quizTypeId);
    int answeredQuizzes = quizTypeData.values
        .where((quiz) => (quiz as Map<String, dynamic>)['total'] > 0)
        .length;

    double progress = totalQuizzes > 0 ? answeredQuizzes / totalQuizzes : 0.0;
    return {
      'progress': progress,
      'answeredCount': answeredQuizzes,
      'totalCount': totalQuizzes
    };
  }
}
