import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import 'package:logger/logger.dart';

class QuizPage extends StatelessWidget {
  final String subjectId;
  final String quizTypeId;

  const QuizPage({Key? key, required this.subjectId, required this.quizTypeId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final quizService = Provider.of<QuizService>(context, listen: false);
    final logger = Provider.of<Logger>(context, listen: false);

    logger.i(
        'Building QuizPage for subjectId: $subjectId, quizTypeId: $quizTypeId');

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz'),
      ),
      body: StreamBuilder<List<Quiz>>(
        stream: quizService.getQuizzes(subjectId, quizTypeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            logger.i('Waiting for quizzes data');
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            logger.w(
                'No quizzes available for subjectId: $subjectId, quizTypeId: $quizTypeId');
            return const Center(child: Text('No quizzes available'));
          }
          logger.i(
              'Quizzes loaded successfully. Count: ${snapshot.data!.length}');
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final quiz = snapshot.data![index];
              return QuizCard(quiz: quiz);
            },
          );
        },
      ),
    );
  }
}
