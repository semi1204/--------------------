// quiz_type_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/subject.dart';
import '../models/quiz_type.dart';
import 'quiz_page.dart';
import 'package:logger/logger.dart';

class QuizTypePage extends StatelessWidget {
  final Subject subject;

  const QuizTypePage({Key? key, required this.subject}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final quizService = Provider.of<QuizService>(context, listen: false);
    final logger = Provider.of<Logger>(context, listen: false);

    logger.i('Building QuizTypePage for subject: ${subject.name}');

    return Scaffold(
      appBar: AppBar(
        title: Text(subject.name),
      ),
      body: StreamBuilder<List<QuizType>>(
        stream: quizService.getQuizTypes(subject.id),
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
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final quizType = snapshot.data![index];
              return ListTile(
                title: Text(quizType.name),
                onTap: () {
                  logger.i('User tapped on quiz type: ${quizType.name}');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizPage(quizType: quizType),
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
}
