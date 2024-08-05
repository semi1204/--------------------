import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/subject.dart';
import 'quiz_type_page.dart';
import 'package:logger/logger.dart';

class SubjectPage extends StatelessWidget {
  final Logger _logger = Logger();

  SubjectPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    _logger.i('Building SubjectPage');
    final quizService = Provider.of<QuizService>(context, listen: false);

    return FutureBuilder<List<Subject>>(
      future: quizService.getSubjects(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          _logger.d('Waiting for subjects data');
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          _logger.e('Error loading subjects: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          _logger.w('No subjects available');
          return const Center(child: Text('No subjects available'));
        }

        final subjects = snapshot.data!;
        _logger.i('Loaded ${subjects.length} subjects');

        return ListView.builder(
          itemCount: subjects.length,
          itemBuilder: (context, index) {
            final subject = subjects[index];
            return ListTile(
              title: Text(subject.name),
              onTap: () {
                _logger.i('Tapped on subject: ${subject.name}');
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
