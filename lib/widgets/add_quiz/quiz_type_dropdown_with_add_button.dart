import 'package:flutter/material.dart';
import '../../services/quiz_service.dart';
import 'package:logger/logger.dart';
import '../../models/quiz_type.dart';

class QuizTypeDropdownWithAddButton extends StatelessWidget {
  final QuizService quizService;
  final Logger logger;
  final String selectedSubjectId;
  final String? selectedTypeId;
  final Function(String?) onChanged;
  final VoidCallback onAddPressed;

  const QuizTypeDropdownWithAddButton({
    super.key,
    required this.quizService,
    required this.logger,
    required this.selectedSubjectId,
    required this.selectedTypeId,
    required this.onChanged,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FutureBuilder<List<QuizType>>(
            future: quizService.getQuizTypes(selectedSubjectId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                logger.i('Waiting for quiz types data');
                return const CircularProgressIndicator();
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                logger.w('No quiz types available for selected subject');
                return const Text('No quiz types available');
              }
              logger.i('Quiz types loaded. Count: ${snapshot.data!.length}');
              return DropdownButtonFormField<String>(
                value: selectedTypeId,
                decoration: const InputDecoration(
                  labelText: 'Select Quiz Type',
                  border: OutlineInputBorder(),
                ),
                items: snapshot.data!.map((QuizType type) {
                  return DropdownMenuItem<String>(
                    value: type.id,
                    child: Text(type.name),
                  );
                }).toList(),
                onChanged: onChanged,
                validator: (value) =>
                    value == null ? 'Please select a quiz type' : null,
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
