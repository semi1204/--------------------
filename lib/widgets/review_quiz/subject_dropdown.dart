import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/quiz_service.dart';
import '../../models/subject.dart';
import 'package:logger/logger.dart';

class SubjectDropdown extends StatelessWidget {
  final String? selectedSubjectId;
  final Function(String?) onSubjectSelected;

  const SubjectDropdown({
    super.key,
    required this.selectedSubjectId,
    required this.onSubjectSelected,
  });

  @override
  Widget build(BuildContext context) {
    final QuizService quizService =
        Provider.of<QuizService>(context, listen: false);
    final Logger logger = Provider.of<Logger>(context, listen: false);

    return FutureBuilder<List<Subject>>(
      future: quizService.getSubjects(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('과목이 없습니다');
        }
        return DropdownButton<String>(
          value: selectedSubjectId,
          hint: const Text('과목을 선택하세요'),
          onChanged: (String? newValue) {
            logger.i('선택된 과목: $newValue');
            onSubjectSelected(newValue);
          },
          items:
              snapshot.data!.map<DropdownMenuItem<String>>((Subject subject) {
            return DropdownMenuItem<String>(
              value: subject.id,
              child: Text(subject.name),
            );
          }).toList(),
        );
      },
    );
  }
}
