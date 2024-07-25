import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/pages/quiz_type_page.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/subject.dart';
import 'package:logger/logger.dart';

class SubjectPage extends StatelessWidget {
  const SubjectPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final quizService = Provider.of<QuizService>(context);
    final logger = Provider.of<Logger>(context, listen: false);

    logger.i('Building SubjectPage');

    return StreamBuilder<List<Subject>>(
      stream: quizService.getSubjects(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          logger.i('Waiting for subjects data');
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          logger.w('No subjects available');
          return const Center(child: Text('No subjects available'));
        }
        logger
            .i('Subjects loaded successfully. Count: ${snapshot.data!.length}');
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final subject = snapshot.data![index];
            return ListTile(
              title: Text(subject.name),
              onTap: () {
                logger.i('User tapped on subject: ${subject.name}');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuizTypePage(subject: subject),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
