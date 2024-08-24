import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../services/quiz_service.dart';
import 'user_provider.dart';
import 'package:logger/logger.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class QuizProvider with ChangeNotifier {
  final QuizService _quizService;
  final UserProvider _userProvider;
  final Logger _logger;

  List<Quiz> _quizzes = [];
  final Map<String, int?> _selectedAnswers = {};
  bool _rebuildExplanation = false;
  bool _isAppBarVisible = true;
  int _lastScrollIndex = 0;
  final ItemScrollController scrollController = ItemScrollController();

  QuizProvider(this._quizService, this._userProvider, this._logger);

  List<Quiz> get quizzes => _quizzes;
  Map<String, int?> get selectedAnswers => _selectedAnswers;
  bool get rebuildExplanation => _rebuildExplanation;
  bool get isAppBarVisible => _isAppBarVisible;
  int get lastScrollIndex => _lastScrollIndex;

  // 퀴즈를 로딩하고, 초기 스크롤 위치를 설정
  // 초기 스크롤 위치는 마지막으로 푼 퀴즈의 다음 퀴즈로 설정
  Future<void> loadQuizzesAndSetInitialScroll(
      String subjectId, String quizTypeId) async {
    _logger.i('퀴즈 로딩 및 초기 스크롤 위치 설정 시작');
    try {
      _quizzes = await _quizService.getQuizzes(subjectId, quizTypeId);
      _loadSavedAnswers(subjectId, quizTypeId);
      _lastScrollIndex = _findLastAnsweredQuizIndex(subjectId, quizTypeId);
      notifyListeners();

      // 스크롤 위치 설정을 약간 지연
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_lastScrollIndex > 0 && scrollController.isAttached) {
          scrollController.scrollTo(
            index: _lastScrollIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });

      _logger.i(
          'Loaded ${_quizzes.length} quizzes, initial scroll index: $_lastScrollIndex');
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

  void setAppBarVisibility(bool isVisible) {
    _isAppBarVisible = isVisible;
    notifyListeners();
  }

  void setLastScrollIndex(int index) {
    _lastScrollIndex = index;
    notifyListeners();
  }

  void scrollToNextQuiz(int currentIndex) {
    if (currentIndex < _quizzes.length - 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollController.scrollTo(
          index: currentIndex + 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  void selectAnswer(String subjectId, String quizTypeId, String quizId,
      int answerIndex, int currentIndex) {
    _logger.i('퀴즈 정답 선택: $quizId, 정답: $answerIndex');
    _selectedAnswers[quizId] = answerIndex;
    _userProvider.updateUserQuizData(
      subjectId,
      quizTypeId,
      quizId,
      answerIndex ==
          _quizzes.firstWhere((q) => q.id == quizId).correctOptionIndex,
      selectedOptionIndex: answerIndex,
    );
    notifyListeners();
    scrollToNextQuiz(currentIndex);
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
    await _quizService.deleteQuiz(
        subjectId, quizTypeId, quizId); // service.deleteQuiz 호출
    _quizzes.removeWhere((q) => q.id == quizId);
    notifyListeners();
    _logger.i('퀴즈 삭제: $quizId');
  }
}