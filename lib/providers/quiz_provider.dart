import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../services/quiz_service.dart';
import 'user_provider.dart';
import 'package:logger/logger.dart';

enum SortOption { all, low, medium, high }

class QuizProvider with ChangeNotifier {
  final QuizService _quizService;
  final UserProvider _userProvider;
  final Logger _logger;

  List<Quiz> _quizzes = [];
  final Map<String, int?> _selectedAnswers = {};
  bool _rebuildExplanation = false;
  int _lastScrollIndex = 0;
  SortOption _currentSortOption = SortOption.all;
  bool _isFilterEmpty = true;
  bool get isFilterEmpty => _isFilterEmpty;

  QuizProvider(this._quizService, this._userProvider, this._logger);

  List<Quiz> get quizzes => _quizzes;
  Map<String, int?> get selectedAnswers => _selectedAnswers;
  bool get rebuildExplanation => _rebuildExplanation;
  int get lastScrollIndex => _lastScrollIndex;
  SortOption get currentSortOption => _currentSortOption;

  void setSortOption(SortOption option) {
    _currentSortOption = option;
    _filterQuizzes();
    notifyListeners();
  }

  void _filterQuizzes() {
    switch (_currentSortOption) {
      case SortOption.all:
        _quizzes = List.from(_quizzes);
        _isFilterEmpty = false;
        break;
      case SortOption.low:
        filterQuizzesByAccuracy(0, 0.6);
        _isFilterEmpty = _quizzes.isEmpty;
        break;
      case SortOption.medium:
        filterQuizzesByAccuracy(0.6, 0.85);
        _isFilterEmpty = _quizzes.isEmpty;
        break;
      case SortOption.high:
        filterQuizzesByAccuracy(0.85, 1.0);
        _isFilterEmpty = _quizzes.isEmpty;
        break;
    }
    notifyListeners();
  }

  void filterQuizzesByAccuracy(double minAccuracy, double maxAccuracy) {
    _logger
        .i('Filtering quizzes by accuracy: min=$minAccuracy, max=$maxAccuracy');

    if (_selectedSubjectId == null || _selectedQuizTypeId == null) {
      _logger.w('Cannot filter quizzes: Subject or QuizType not selected');
      return;
    }

    _quizzes = _quizzes.where((quiz) {
      double accuracy = _userProvider.getQuizAccuracy(
        _selectedSubjectId!,
        _selectedQuizTypeId!,
        quiz.id,
      );

      _logger.d('Quiz ${quiz.id} accuracy: $accuracy');

      // 정확도가 1.0인 경우를 포함하도록 수정
      return accuracy >= minAccuracy && accuracy <= maxAccuracy;
    }).toList();

    _logger.i('Quizzes filtered. New count: ${_quizzes.length}');
    _isFilterEmpty = _quizzes.isEmpty;
  }

  // 퀴즈를 로딩하고, 초기 화면 위치를 설정
  // 초기 화면의 위치는 마지막으로 푼 퀴즈의 다음 퀴즈로 설정
  Future<void> loadQuizzesAndSetInitialScroll(
      String subjectId, String quizTypeId) async {
    //_logger.i('퀴즈 로딩 및 초기 스크롤 위치 설정 시작');
    try {
      _quizzes = await _quizService.getQuizzes(subjectId, quizTypeId);
      _loadSavedAnswers(subjectId, quizTypeId);
      _lastScrollIndex = _findLastAnsweredQuizIndex(subjectId, quizTypeId);
      notifyListeners();
      //_logger.i(
      //    'Loaded ${_quizzes.length} quizzes, initial scroll index: $_lastScrollIndex');
    } catch (e) {
      _logger.e('Error loading quizzes: $e');
    }
  }

  int _findLastAnsweredQuizIndex(String subjectId, String quizTypeId) {
    final userData = _userProvider.getUserQuizData();
    for (int i = 0; i < _quizzes.length; i++) {
      final quizData = userData[subjectId]?[quizTypeId]?[_quizzes[i].id];
      if (quizData == null || quizData['selectedOptionIndex'] == null) {
        return i; // 첫 번째 미응답 퀴즈의 인덱스 반환
      }
    }
    return _quizzes.length; // 모든 퀴즈에 응답했다면 마지막 인덱스 반환
  }

  void _loadSavedAnswers(String subjectId, String quizTypeId) {
    final userData = _userProvider.getUserQuizData();
    for (var quiz in _quizzes) {
      final quizData = userData[subjectId]?[quizTypeId]?[quiz.id];
      if (quizData != null && quizData is Map<String, dynamic>) {
        _selectedAnswers[quiz.id] = quizData['selectedOptionIndex'] as int?;
      }
    }
  }

  void setLastScrollIndex(int index) {
    _lastScrollIndex = index;
  }

  void selectAnswer(
      String subjectId, String quizTypeId, String quizId, int answerIndex) {
    //_logger.i('퀴즈 정답 선택: $quizId, 정답: $answerIndex');
    _selectedAnswers[quizId] = answerIndex;
    _userProvider.updateUserQuizData(
      subjectId,
      quizTypeId,
      quizId,
      answerIndex ==
          _quizzes.firstWhere((q) => q.id == quizId).correctOptionIndex,
      selectedOptionIndex: answerIndex,
    );
    updateQuizAccuracy(subjectId, quizTypeId, quizId);
    notifyListeners();
  }

  void resetQuiz(String subjectId, String quizTypeId, String quizId) {
    _selectedAnswers[quizId] = null;
    _rebuildExplanation = !_rebuildExplanation;
    _userProvider.resetUserAnswers(subjectId, quizTypeId, quizId);
    notifyListeners();
    _logger.i('퀴즈 리셋: $quizId');
  }

  Future<void> deleteQuiz(
      String subjectId, String quizTypeId, String quizId) async {
    await _quizService.deleteQuiz(subjectId, quizTypeId, quizId);
    _quizzes.removeWhere((q) => q.id == quizId);
    notifyListeners();
    _logger.i('퀴즈 삭제: $quizId');
  }

  // Add these properties if they don't exist
  String? _selectedSubjectId;
  String? _selectedQuizTypeId;

  // Add these methods if they don't exist
  void setSelectedSubjectId(String subjectId) {
    _selectedSubjectId = subjectId;
    notifyListeners();
  }

  void setSelectedQuizTypeId(String quizTypeId) {
    _selectedQuizTypeId = quizTypeId;
    notifyListeners();
  }

  void updateQuizAccuracy(String subjectId, String quizTypeId, String quizId) {
    notifyListeners();
  }

  void resetSortOption() {
    _currentSortOption = SortOption.all;
    _filterQuizzes();
  }
}
