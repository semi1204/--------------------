// quiz_type_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/subject.dart';
import '../models/quiz_type.dart';
import 'quiz_page.dart';
import 'package:logger/logger.dart';
import '../widgets/close_button.dart'; // CustomCloseButton import

class QuizTypePage extends StatelessWidget {
  final Subject subject;

  const QuizTypePage({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final quizService = Provider.of<QuizService>(context, listen: false);
    final logger = Provider.of<Logger>(context, listen: false);

    logger.i('Building QuizTypePage for subject: ${subject.name}');

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight / 1.4),
        child: AppBar(
          title: Text(
            subject.name,
            style: const TextStyle(fontSize: 18),
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
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final quizType = snapshot.data![index];
              return Card(
                elevation: 0.5,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(
                    quizType.name,
                    style: const TextStyle(fontSize: 14),
                  ),
                  onTap: () {
                    logger.i('User tapped on quiz type: ${quizType.name}');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizPage(
                          subjectId: subject.id,
                          quizTypeId: quizType.id,
                        ),
                      ),
                    );
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
