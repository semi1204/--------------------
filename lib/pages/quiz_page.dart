// quiz_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz_type.dart';
import '../models/quiz.dart';
import 'package:logger/logger.dart';

class QuizPage extends StatelessWidget {
  final QuizType quizType;

  const QuizPage({Key? key, required this.quizType}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final quizService = Provider.of<QuizService>(context, listen: false);
    final logger = Provider.of<Logger>(context, listen: false);

    logger.i('Building QuizPage for quiz type: ${quizType.name}');

    return Scaffold(
      appBar: AppBar(
        title: Text(quizType.name),
      ),
      body: StreamBuilder<List<Quiz>>(
        stream: quizService.getQuizzes(quizType.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            logger.i('Waiting for quizzes data');
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            logger.w('No quizzes available for quiz type: ${quizType.name}');
            return const Center(child: Text('No quizzes available'));
          }
          logger.i(
              'Quizzes loaded successfully. Count: ${snapshot.data!.length}');
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final quiz = snapshot.data![index];
              return Card(
                child: ListTile(
                  title: Text(quiz.question),
                  onTap: () {
                    logger.i('User tapped on quiz: ${quiz.question}');
                    // TODO: Implement quiz taking logic
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
