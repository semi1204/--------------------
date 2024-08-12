import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/quiz_service.dart';
import '../models/subject.dart';
import 'quiz_type_page.dart';
import 'package:logger/logger.dart';

class SubjectPage extends StatelessWidget {
  final Logger _logger = Logger();

  SubjectPage({super.key});

  @override
  Widget build(BuildContext context) {
    _logger.i('Building SubjectPage');
    final quizService = Provider.of<QuizService>(context, listen: false);

    return FutureBuilder<List<Subject>>(
      future: quizService.getSubjects(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          _logger.d('과목 데이터 대기 중');
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          _logger.e('과목 데이터 로드 실패: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          _logger.w('과목 없음');
          return const Center(child: Text('과목 없음'));
        }

        final subjects = snapshot.data!;
        _logger.i('과목 ${subjects.length}개 로드 완료');

        return ListView.builder(
          itemCount: subjects.length,
          itemBuilder: (context, index) {
            final subject = subjects[index];
            return Card(
              elevation: 0.5,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(subject.name),
                onTap: () {
                  _logger.i('과목 ${subject.name} 클릭');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizTypePage(subject: subject),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
