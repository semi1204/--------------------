import 'package:flutter/material.dart';
import 'package:nursing_quiz_app_6/services/analytics_service.dart';
import 'package:nursing_quiz_app_6/services/payment_service.dart';
import '../models/quiz.dart';
import '../services/quiz_service.dart';
import 'user_provider.dart';
import 'package:logger/logger.dart';

enum SortOption { all, low, medium, high }

class QuizProvider with ChangeNotifier {
  final QuizService _quizService;
  final UserProvider _userProvider;
  final Logger _logger;
  final PaymentService _paymentService;
  final AnalyticsService? _analytics;

  List<Quiz> _allQuizzes = [];
  List<Quiz> _filteredQuizzes = [];
  bool _isLoading = true;
  final Map<String, int?> _selectedAnswers = {};
  bool _rebuildExplanation = false;
  int _lastScrollIndex = 0;
  SortOption _currentSortOption = SortOption.all;
  bool _isFilterEmpty = true;
  bool _showOXOnly = false;

  String? _selectedSubjectId;
  String? _selectedQuizTypeId;

  QuizProvider(
      this._quizService, this._userProvider, this._logger, this._paymentService,
      [this._analytics]);

  List<Quiz> get quizzes => _filteredQuizzes;
  Map<String, int?> get selectedAnswers => _selectedAnswers;
  bool get rebuildExplanation => _rebuildExplanation;
  int get lastScrollIndex => _lastScrollIndex;
  SortOption get currentSortOption => _currentSortOption;
  bool get isFilterEmpty => _isFilterEmpty;
  bool get showOXOnly => _showOXOnly;
  bool get isLoading => _isLoading;

  void setSortOption(SortOption option) {
    _currentSortOption = option;
    _filterQuizzes();
    notifyListeners();
  }

  void _filterQuizzes() {
    _filteredQuizzes = _allQuizzes.where((quiz) {
      // Filter based on quiz type (OX or math)
      if (_showOXOnly != quiz.isOX) {
        return false;
      }

      // Apply additional filters (if any)
      switch (_currentSortOption) {
        case SortOption.all:
          return true;
        case SortOption.low:
          return _getQuizAccuracy(quiz) < 0.2;
        case SortOption.medium:
          final accuracy = _getQuizAccuracy(quiz);
          return accuracy >= 0.2 && accuracy < 0.6;
        case SortOption.high:
          return _getQuizAccuracy(quiz) >= 0.6;
      }
    }).toList();
    _isFilterEmpty = _filteredQuizzes.isEmpty;
  }

  double _getQuizAccuracy(Quiz quiz) {
    return _userProvider.getQuizAccuracy(
      _selectedSubjectId!,
      _selectedQuizTypeId!,
      quiz.id,
    );
  }

  void filterQuizzes({bool? showOXOnly}) {
    if (showOXOnly != null) _showOXOnly = showOXOnly;
    _filterQuizzes();
    notifyListeners();
  }

  Future<void> loadQuizzesAndSetInitialScroll(
      String subjectId, String quizTypeId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _allQuizzes = await _quizService.getQuizzes(subjectId, quizTypeId,
          forceRefresh: true);
      _loadSavedAnswers(subjectId, quizTypeId);
      _lastScrollIndex = _findLastAnsweredQuizIndex(subjectId, quizTypeId);
      _filterQuizzes();
    } catch (e) {
      _logger.e('Error loading quizzes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  int _findLastAnsweredQuizIndex(String subjectId, String quizTypeId) {
    final userData = _userProvider.getUserQuizData();
    for (int i = 0; i < _allQuizzes.length; i++) {
      final quizData = userData[subjectId]?[quizTypeId]?[_allQuizzes[i].id];
      if (quizData == null || quizData['selectedOptionIndex'] == null) {
        return i;
      }
    }
    return _allQuizzes.length;
  }

  void _loadSavedAnswers(String subjectId, String quizTypeId) {
    final userData = _userProvider.getUserQuizData();
    for (var quiz in _allQuizzes) {
      final quizData = userData[subjectId]?[quizTypeId]?[quiz.id];
      if (quizData != null && quizData is Map<String, dynamic>) {
        _selectedAnswers[quiz.id] = quizData['selectedOptionIndex'] as int?;
      }
    }
  }

  void setLastScrollIndex(int index) {
    _lastScrollIndex = index;
  }

  Future<void> selectAnswer(String subjectId, String quizTypeId, String quizId,
      int answerIndex) async {
    // 먼저 답변을 저장
    _selectedAnswers[quizId] = answerIndex;

    // payment 관련 처리
    if (!_userProvider.isSubscribed) {
      final canAttempt = await _paymentService.canAttemptQuiz();
      if (!canAttempt) {
        _logger.w('User cannot attempt more quizzes without subscription');
        // 답변은 저장되지만 추가 시도는 제한됨
        return;
      }
      await _paymentService.incrementQuizAttempt();
    }

    // 사용자 데이터 업데이트
    await _userProvider.updateUserQuizData(
      subjectId,
      quizTypeId,
      quizId,
      answerIndex ==
          _allQuizzes.firstWhere((q) => q.id == quizId).correctOptionIndex,
      selectedOptionIndex: answerIndex,
    );

    updateQuizAccuracy(subjectId, quizTypeId, quizId);
    notifyListeners();
  }

  Future<void> deleteQuiz(
      String subjectId, String quizTypeId, String quizId) async {
    await _quizService.deleteQuiz(subjectId, quizTypeId, quizId);
    _allQuizzes.removeWhere((q) => q.id == quizId);
    notifyListeners();
    _logger.i('퀴즈 삭제: $quizId');
  }

  void setSelectedSubjectId(String subjectId) {
    _selectedSubjectId = subjectId;
    notifyListeners();
  }

  void setSelectedQuizTypeId(String quizTypeId) {
    _selectedQuizTypeId = quizTypeId;
    _showOXOnly = quizTypeId ==
        'ox_quiz_type_id'; // Replace with your actual OX quiz type ID
    _filterQuizzes();
    notifyListeners();
  }

  void updateQuizAccuracy(String subjectId, String quizTypeId, String quizId) {
    notifyListeners();
  }

  void resetSortOption() {
    _currentSortOption = SortOption.all;
    _showOXOnly = false;
    _filterQuizzes();
    notifyListeners();
  }

  Future<Quiz?> getQuizById(
      String subjectId, String quizTypeId, String quizId) async {
    return await _quizService.getQuizById(subjectId, quizTypeId, quizId);
  }

  void toggleQuizType(bool showOXOnly) {
    _showOXOnly = showOXOnly;
    _filterQuizzes();
    notifyListeners();
  }

  // Add this method to reload specific quiz data
  Future<void> reloadQuizData(
      String subjectId, String quizTypeId, String quizId) async {
    final userData = _userProvider.getUserQuizData();
    final quizData = userData[subjectId]?[quizTypeId]?[quizId];
    if (quizData != null && quizData is Map<String, dynamic>) {
      _selectedAnswers[quizId] = quizData['selectedOptionIndex'] as int?;
    } else {
      _selectedAnswers.remove(quizId);
    }
    notifyListeners();
  }

  Future<void> resetSelectedOption(
      String subjectId, String quizTypeId, String quizId) async {
    try {
      _selectedAnswers.remove(quizId);
      _rebuildExplanation = !_rebuildExplanation;

      if (_userProvider.user == null) {
        _logger.w('Cannot reset option: No user logged in');
        return;
      }

      await _quizService.resetSelectedOption(
          _userProvider.user!.uid, subjectId, quizTypeId, quizId);

      notifyListeners();
      _logger.i('Quiz option reset completed: $quizId');
    } catch (e) {
      _logger.e('Error resetting quiz option: $e');
      rethrow;
    }
  }

  Future<void> submitAnswer(
    String subjectId,
    String quizTypeId,
    String quizId,
    int answerIndex,
    int timeSpent,
  ) async {
    final isCorrect = answerIndex ==
        _allQuizzes.firstWhere((q) => q.id == quizId).correctOptionIndex;

    // Analytics 이벤트 로깅
    if (_analytics != null) {
      await _analytics!.logQuizCompleted(
        quizId: quizId,
        subjectId: subjectId,
        isCorrect: isCorrect,
        timeSpent: timeSpent,
      );
    }
  }
}
