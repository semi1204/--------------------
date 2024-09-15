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

  QuizProvider(this._quizService, this._userProvider, this._logger);

  List<Quiz> get quizzes => _quizzes;
  Map<String, int?> get selectedAnswers => _selectedAnswers;
  bool get rebuildExplanation => _rebuildExplanation;
  int get lastScrollIndex => _lastScrollIndex;
  SortOption get currentSortOption => _currentSortOption;

  void setSortOption(SortOption option) {
    _currentSortOption = option;
    _sortQuizzes();
    notifyListeners();
  }

  void _sortQuizzes() {
    switch (_currentSortOption) {
      case SortOption.all:
        // 원래 순서로 복원
        _quizzes.sort((a, b) => a.id.compareTo(b.id));
        break;
      case SortOption.low:
        sortQuizzesByAccuracy(0, 0.6);
        break;
      case SortOption.medium:
        sortQuizzesByAccuracy(0.6, 0.85);
        break;
      case SortOption.high:
        sortQuizzesByAccuracy(0.85, 1.0);
        break;
    }
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

  void sortQuizzesByAccuracy(double minAccuracy, double maxAccuracy) {
    _logger
        .i('Sorting quizzes by accuracy: min=$minAccuracy, max=$maxAccuracy');

    if (_selectedSubjectId == null || _selectedQuizTypeId == null) {
      _logger.w('Cannot sort quizzes: Subject or QuizType not selected');
      return;
    }

    _quizzes.sort((a, b) {
      double accuracyA = _userProvider.getQuizAccuracy(
        _selectedSubjectId!,
        _selectedQuizTypeId!,
        a.id,
      );
      double accuracyB = _userProvider.getQuizAccuracy(
        _selectedSubjectId!,
        _selectedQuizTypeId!,
        b.id,
      );

      _logger.d('Quiz ${a.id} accuracy: $accuracyA');
      _logger.d('Quiz ${b.id} accuracy: $accuracyB');

      bool isAInRange = accuracyA >= minAccuracy && accuracyA < maxAccuracy;
      bool isBInRange = accuracyB >= minAccuracy && accuracyB < maxAccuracy;

      if (isAInRange && isBInRange) {
        // 둘 다 범위 내에 있으면 정확도가 높은 순으로 정렬
        return accuracyB.compareTo(accuracyA);
      } else if (isAInRange) {
        // A만 범위 내에 있으면 A를 앞으로
        return -1;
      } else if (isBInRange) {
        // B만 범위 내에 있으면 B를 앞으로
        return 1;
      } else {
        // 둘 다 범위 밖이면 원래 순서 유지
        return 0;
      }
    });

    _logger
        .i('Quizzes sorted. New order: ${_quizzes.map((q) => q.id).toList()}');
    notifyListeners();
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
}
