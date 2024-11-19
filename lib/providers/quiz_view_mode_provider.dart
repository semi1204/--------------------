import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuizViewModeProvider with ChangeNotifier {
  bool _isOneByOne = false;
  int _currentIndex = 0;
  String? _currentQuizId;

  bool get isOneByOne => _isOneByOne;
  int get currentIndex => _currentIndex;
  String? get currentQuizId => _currentQuizId;

  QuizViewModeProvider() {
    _loadPreference();
  }

  void setCurrentQuizPosition(int index, String quizId) {
    _currentIndex = index;
    _currentQuizId = quizId;
    notifyListeners();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isOneByOne = prefs.getBool('isOneByOne') ?? false;
    notifyListeners();
  }

  Future<void> toggleViewMode() async {
    _isOneByOne = !_isOneByOne;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOneByOne', _isOneByOne);
    notifyListeners();
  }

  void nextQuiz() {
    _currentIndex++;
    notifyListeners();
  }

  void previousQuiz() {
    if (_currentIndex > 0) {
      _currentIndex--;
      notifyListeners();
    }
  }

  void resetIndex() {
    _currentIndex = 0;
    notifyListeners();
  }
}
