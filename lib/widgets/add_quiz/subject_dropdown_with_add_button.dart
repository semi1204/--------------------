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
                logger.i('Waiting for subjects data');
                return const CircularProgressIndicator();
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                logger.w('No subjects available');
                return const Text('No subjects available');
              }
              logger.i('Subjects loaded. Count: ${snapshot.data!.length}');
              return DropdownButtonFormField<String>(
                value: selectedSubjectId,
                decoration: const InputDecoration(
                  labelText: 'Select Subject',
                  border: OutlineInputBorder(),
                ),
                items: snapshot.data!.map((Subject subject) {
                  return DropdownMenuItem<String>(
                    value: subject.id,
                    child: Text(subject.name),
                  );
                }).toList(),
                onChanged: onChanged,
                validator: (value) =>
                    value == null ? 'Please select a subject' : null,
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
