import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/widgets/quiz_card.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/quiz.dart';
import '../providers/user_provider.dart';
import 'package:logger/logger.dart';
import 'edit_quiz_page.dart';

class QuizPage extends StatelessWidget {
  final String subjectId;
  final String quizTypeId;

  const QuizPage({
    super.key, // Use super.key here
    required this.subjectId,
    required this.quizTypeId,
  });

  @override
  Widget build(BuildContext context) {
    final quizService = Provider.of<QuizService>(context, listen: false);
    final logger = Provider.of<Logger>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    logger.i(
        'Building QuizPage for subjectId: $subjectId, quizTypeId: $quizTypeId');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
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
              logger.d('Creating QuizCard for quiz ${index + 1}: ${quiz.id}');
              return QuizCard(
                quiz: quiz,
                isAdmin: userProvider.isAdmin,
                onEdit: () => _editQuiz(context, quiz),
                onDelete: () => _deleteQuiz(context, quiz),
                questionNumber: index + 1,
              );
            },
          );
        },
      ),
    );
  }

  void _editQuiz(BuildContext context, Quiz quiz) {
    final logger = Provider.of<Logger>(context, listen: false);
    logger.i('Editing quiz: ${quiz.id}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditQuizPage(
          quiz: quiz,
          subjectId: subjectId,
          quizTypeId: quizTypeId,
        ),
      ),
    );
  }

  void _deleteQuiz(BuildContext context, Quiz quiz) {
    final quizService = Provider.of<QuizService>(context, listen: false);
    final logger = Provider.of<Logger>(context, listen: false);
    logger.i('Deleting quiz: ${quiz.id}');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Quiz'),
          content: const Text('Are you sure you want to delete this quiz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                quizService.deleteQuiz(subjectId, quizTypeId, quiz.id);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
