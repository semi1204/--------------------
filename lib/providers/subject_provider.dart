import 'package:flutter/foundation.dart';
import '../models/subject.dart';
import '../services/quiz_service.dart';

class SubjectProvider with ChangeNotifier {
  List<Subject> _subjects = [];
  int _selectedIndex = 0;

  List<Subject> get subjects => _subjects;
  int get selectedIndex => _selectedIndex;

  final QuizService _quizService = QuizService();

  Future<void> loadSubjects() async {
    _subjects = await _quizService.getSubjects();
    notifyListeners();
  }

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }
}
