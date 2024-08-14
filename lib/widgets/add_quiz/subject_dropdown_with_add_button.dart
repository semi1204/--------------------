import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/quiz_service.dart';
import '../../models/subject.dart';
import 'package:logger/logger.dart';

class UnifiedSubjectDropdown extends StatelessWidget {
  final String? selectedSubjectId;
  final Function(String?) onSubjectSelected;
  final VoidCallback? onAddPressed;
  final bool showAddButton;
  final bool useFormField;

  const UnifiedSubjectDropdown({
    super.key,
    required this.selectedSubjectId,
    required this.onSubjectSelected,
    this.onAddPressed,
    this.showAddButton = false,
    this.useFormField = false,
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
          logger.i('과목 데이터 대기 중');
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          logger.e('과목 데이터 로드 실패: ${snapshot.error}');
          return const Text('과목 데이터를 불러오는 데 실패했습니다.');
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          logger.w('과목 데이터 없음');
          return const Text('사용 가능한 과목이 없습니다.');
        }
        logger.i('과목 로드 완료. 개수: ${snapshot.data!.length}');

        final subjects = snapshot.data!;
        Widget dropdownWidget;
        if (useFormField) {
          dropdownWidget = DropdownButtonFormField<String>(
            value: selectedSubjectId,
            decoration: const InputDecoration(
              labelText: '과목 선택',
              border: OutlineInputBorder(),
            ),
            items: _buildDropdownItems(subjects),
            onChanged: (String? newValue) {
              final selectedSubject =
                  subjects.firstWhere((s) => s.id == newValue);
              logger.i('선택된 과목: ${selectedSubject.name} (ID: $newValue)');
              onSubjectSelected(newValue);
            },
            validator: (value) => value == null ? '과목을 선택해주세요' : null,
          );
        } else {
          dropdownWidget = DropdownButton<String>(
            value: selectedSubjectId,
            hint: const Text('과목을 선택하세요'),
            items: _buildDropdownItems(subjects),
            onChanged: (String? newValue) {
              final selectedSubject =
                  subjects.firstWhere((s) => s.id == newValue);
              logger.i('선택된 과목: ${selectedSubject.name} (ID: $newValue)');
              onSubjectSelected(newValue);
            },
          );
        }

        if (showAddButton) {
          return Row(
            children: [
              Expanded(child: dropdownWidget),
              if (onAddPressed != null)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: onAddPressed,
                ),
            ],
          );
        } else {
          return dropdownWidget;
        }
      },
    );
  }

  List<DropdownMenuItem<String>> _buildDropdownItems(List<Subject> subjects) {
    return subjects.map<DropdownMenuItem<String>>((Subject subject) {
      return DropdownMenuItem<String>(
        value: subject.id,
        child: Text(subject.name),
      );
    }).toList();
  }
}
