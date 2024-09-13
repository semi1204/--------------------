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
    Key? key,
    required this.selectedSubjectId,
    required this.onSubjectSelected,
    this.onAddPressed,
    this.showAddButton = false,
    this.useFormField = false,
  }) : super(key: key);

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
          return const Center(child: CircularProgressIndicator());
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

        Widget dropdownWidget = _buildModernDropdown(context, subjects);

        if (showAddButton) {
          return Row(
            children: [
              Expanded(child: dropdownWidget),
              if (onAddPressed != null)
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  color: Theme.of(context).primaryColor,
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

  Widget _buildModernDropdown(BuildContext context, List<Subject> subjects) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: useFormField
            ? DropdownButtonFormField<String>(
                value: selectedSubjectId,
                decoration: InputDecoration(
                  labelText: '과목 선택',
                  border: InputBorder.none,
                  labelStyle: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 18,
                  ),
                ),
                items: _buildDropdownItems(subjects),
                onChanged: _onSubjectChanged,
                validator: (value) => value == null ? '과목을 선택해주세요' : null,
                icon: Icon(Icons.arrow_drop_down,
                    color: Theme.of(context).primaryColor, size: 30),
                dropdownColor: Colors.grey[100],
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 18,
                ),
                menuMaxHeight: 300,
              )
            : DropdownButton<String>(
                value: selectedSubjectId,
                hint: Text('과목을 선택하세요',
                    style: TextStyle(
                        color: Theme.of(context).hintColor, fontSize: 18)),
                items: _buildDropdownItems(subjects),
                onChanged: _onSubjectChanged,
                icon: Icon(Icons.arrow_drop_down,
                    color: Theme.of(context).primaryColor, size: 30),
                dropdownColor: Colors.grey[100],
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 18,
                ),
                underline: Container(),
                isExpanded: true,
                menuMaxHeight: 300,
              ),
      ),
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

  void _onSubjectChanged(String? newValue) {
    onSubjectSelected(newValue);
  }
}
