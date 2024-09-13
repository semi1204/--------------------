import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/quiz_service.dart';
import '../../models/subject.dart';
import 'package:logger/logger.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';

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
    final ThemeProvider themeProvider = Provider.of<ThemeProvider>(context);

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

        Widget dropdownWidget =
            _buildModernDropdown(context, subjects, themeProvider);

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

  Widget _buildModernDropdown(BuildContext context, List<Subject> subjects,
      ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: themeProvider.isDarkMode
            ? ThemeProvider.darkModeSurface
            : Colors.grey[200],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8), // Increased padding
        child: useFormField
            ? _buildDropdownFormField(context, subjects, themeProvider)
            : _buildDropdownButton(context, subjects, themeProvider),
      ),
    );
  }

  Widget _buildDropdownFormField(BuildContext context, List<Subject> subjects,
      ThemeProvider themeProvider) {
    return DropdownButtonFormField<String>(
      value: selectedSubjectId,
      decoration: InputDecoration(
        labelText: '과목 선택',
        border: InputBorder.none,
        labelStyle: getAppTextStyle(context,
                fontSize: 20,
                fontWeight: FontWeight.bold) // Increased font size
            .copyWith(
          color: ThemeProvider.primaryColor,
        ),
        contentPadding: EdgeInsets.symmetric(
            vertical: 12, horizontal: 16), // Added content padding
      ),
      items: _buildDropdownItems(subjects),
      onChanged: _onSubjectChanged,
      validator: (value) => value == null ? '과목을 선택해주세요' : null,
      icon: const Icon(Icons.arrow_drop_down,
          color: ThemeProvider.primaryColor, size: 36), // Increased icon size
      dropdownColor: themeProvider.isDarkMode
          ? ThemeProvider.darkModeSurface
          : Colors.grey[100],
      style: getAppTextStyle(context, fontSize: 20), // Increased font size
      menuMaxHeight: 300,
      isExpanded: true,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
    );
  }

  Widget _buildDropdownButton(BuildContext context, List<Subject> subjects,
      ThemeProvider themeProvider) {
    return DropdownButton<String>(
      value: selectedSubjectId,
      hint: Text('과목을 선택하세요',
          style: getAppTextStyle(context, fontSize: 17) // Increased font size
              .copyWith(color: Theme.of(context).hintColor)),
      items: _buildDropdownItems(subjects),
      onChanged: _onSubjectChanged,
      icon: const Icon(Icons.arrow_drop_down,
          color: ThemeProvider.primaryColor, size: 36), // Increased icon size
      dropdownColor: themeProvider.isDarkMode
          ? ThemeProvider.darkModeSurface
          : Colors.grey[100],
      style: getAppTextStyle(context, fontSize: 20), // Increased font size
      underline: Container(),
      isExpanded: true,
      menuMaxHeight: 300,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
    );
  }

  List<DropdownMenuItem<String>> _buildDropdownItems(List<Subject> subjects) {
    return subjects.map<DropdownMenuItem<String>>((Subject subject) {
      return DropdownMenuItem<String>(
        value: subject.id,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 8.0), // Added padding to menu items
          child: Text(subject.name),
        ),
      );
    }).toList();
  }

  void _onSubjectChanged(String? newValue) {
    onSubjectSelected(newValue);
  }
}
