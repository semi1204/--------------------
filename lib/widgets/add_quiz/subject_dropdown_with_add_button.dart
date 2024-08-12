import 'package:flutter/material.dart';
import '../../services/quiz_service.dart';
import 'package:logger/logger.dart';
import '../../models/subject.dart';

class SubjectDropdownWithAddButton extends StatelessWidget {
  final QuizService quizService;
  final Logger logger;
  final String? selectedSubjectId;
  final Function(String?) onChanged;
  final VoidCallback onAddPressed;

  const SubjectDropdownWithAddButton({
    super.key,
    required this.quizService,
    required this.logger,
    required this.selectedSubjectId,
    required this.onChanged,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FutureBuilder<List<Subject>>(
            future: quizService.getSubjects(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                logger.i('과목 데이터 대기 중');
                return const CircularProgressIndicator();
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                logger.w('과목 사용 불가');
                return const Text('과목 사용 불가');
              }
              logger.i('과목 로드 완료. 개수: ${snapshot.data!.length}');
              return DropdownButtonFormField<String>(
                value: selectedSubjectId,
                decoration: const InputDecoration(
                  labelText: '과목 선택',
                  border: OutlineInputBorder(),
                ),
                items: snapshot.data!.map((Subject subject) {
                  return DropdownMenuItem<String>(
                    value: subject.id,
                    child: Text(subject.name),
                  );
                }).toList(),
                onChanged: onChanged,
                validator: (value) => value == null ? '과목을 선택해주세요' : null,
              );
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: onAddPressed,
        ),
      ],
    );
  }
}
