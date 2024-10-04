import 'package:flutter/foundation.dart';
import 'package:nursing_quiz_app_6/models/quiz.dart';
import 'package:nursing_quiz_app_6/models/subject.dart';
import 'package:nursing_quiz_app_6/services/quiz_service.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ReviewQuizzesProvider with ChangeNotifier {
  final QuizService _quizService;
  final Logger _logger;
  final String? userId;

  String? _selectedSubjectId;
  List<Quiz> _quizzesForReview = [];
  bool _isLoading = false;
  List<String> _completedQuizIds = [];
  bool _isAllQuizzesCompleted = false;
  List<Subject> _subjects = [];
  Map<String, int> _initialTotalQuizzesPerSubject = {};
  Map<String, int> _currentTotalQuizzesPerSubject = {};
  DateTime _lastResetDate = DateTime.now();

  ReviewQuizzesProvider(this._quizService, this._logger, this.userId) {
    loadSubjects();
    _loadInitialTotalQuizzes();
  }

  String? get selectedSubjectId => _selectedSubjectId;
  List<Quiz> get quizzesForReview => _quizzesForReview;
  bool get isLoading => _isLoading;
  List<String> get completedQuizIds => _completedQuizIds;
  bool get isAllQuizzesCompleted => _isAllQuizzesCompleted;
  List<Subject> get subjects => _subjects;
  int get initialTotalQuizzes =>
      _initialTotalQuizzesPerSubject[_selectedSubjectId] ?? 0;

  void setSelectedSubjectId(String? subjectId) {
    _selectedSubjectId = subjectId;
    notifyListeners();
    if (subjectId != null) {
      loadQuizzesForReview(); // Automatically load quizzes when subject is selected
    }
  }

  Future<void> loadSubjects() async {
    _logger.i('과목 로드 시작');
    try {
      _subjects = await _quizService.getSubjects();
      _logger.i('과목 로드 완료: ${_subjects.length}개');
      notifyListeners();
    } catch (e) {
      _logger.e('과목을 로드하는 중 오류 발생: $e');
    }
  }

  Future<void> _loadInitialTotalQuizzes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedData = prefs.getString('initial_total_quizzes');
    final String? lastResetDateString = prefs.getString('last_reset_date');

    if (storedData != null && lastResetDateString != null) {
      final Map<String, dynamic> decodedData = json.decode(storedData);
      _initialTotalQuizzesPerSubject = Map<String, int>.from(decodedData);
      _lastResetDate = DateTime.parse(lastResetDateString);

      // Check if it's a new day
      if (!_isSameDay(_lastResetDate, DateTime.now())) {
        _resetInitialTotalQuizzes();
      }
    } else {
      _resetInitialTotalQuizzes();
    }
  }

  Future<void> _saveInitialTotalQuizzes() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(_initialTotalQuizzesPerSubject);
    await prefs.setString('initial_total_quizzes', encodedData);
    await prefs.setString('last_reset_date', _lastResetDate.toIso8601String());
  }

  void _resetInitialTotalQuizzes() {
    _initialTotalQuizzesPerSubject.clear();
    _lastResetDate = DateTime.now();
    _saveInitialTotalQuizzes();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> loadQuizzesForReview() async {
    if (_selectedSubjectId == null || userId == null) {
      _logger.w('과목 또는 사용자 ID가 선택되지 않았습니다.');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _logger.d('복습 퀴즈 로드 시작: userId=$userId, subjectId=$_selectedSubjectId');
      _quizzesForReview = await _quizService.getQuizzesForReview(
        userId!,
        _selectedSubjectId!,
        null,
      );

      // Update the initial and current total quizzes for the selected subject
      if (!_initialTotalQuizzesPerSubject.containsKey(_selectedSubjectId) ||
          !_isSameDay(_lastResetDate, DateTime.now())) {
        _initialTotalQuizzesPerSubject[_selectedSubjectId!] =
            _quizzesForReview.length;
        _lastResetDate = DateTime.now();
        await _saveInitialTotalQuizzes();
      }
      _currentTotalQuizzesPerSubject[_selectedSubjectId!] =
          _quizzesForReview.length;

      // Load completed quiz IDs for the current subject
      await _loadCompletedQuizIds();

      _logger.i('복습 카드 ${_quizzesForReview.length}개 로드 완료');
      _logger.d('로드된 퀴즈: ${_quizzesForReview.map((q) => q.id).toList()}');
      _logger.d('완료된 퀴즈: $_completedQuizIds');

      _checkAllQuizzesCompleted();
    } catch (e) {
      _logger.e('퀴즈 복습 데이터를 불러올 수 없음: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCompletedQuizIds() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'completed_quizzes_${userId}_${_selectedSubjectId}';
    _completedQuizIds = prefs.getStringList(key) ?? [];
  }

  Future<void> _saveCompletedQuizIds() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'completed_quizzes_${userId}_${_selectedSubjectId}';
    await prefs.setStringList(key, _completedQuizIds);
  }

  void addCompletedQuizId(String quizId) {
    if (!_completedQuizIds.contains(quizId)) {
      _completedQuizIds.add(quizId);
      _saveCompletedQuizIds();
      _checkAllQuizzesCompleted();
      notifyListeners();
    }
  }

  String getSubjectName(String? subjectId) {
    if (subjectId == null) return "선택된 과목";
    final subject = _subjects.firstWhere((s) => s.id == subjectId,
        orElse: () => Subject(id: '', name: '알 수 없는 과목'));
    return subject.name;
  }

  void removeQuizFromReview(String quizId) {
    _quizzesForReview.removeWhere((quiz) => quiz.id == quizId);
    _checkAllQuizzesCompleted();
    notifyListeners();

    // Added: Trigger synchronization after removing a quiz from review
    if (userId != null) {
      _quizService.syncUserData(userId!, _quizService.getUserQuizData(userId!));
    }
  }

  Future<Map<String, int>> getReviewProgress(String subjectId) async {
    if (userId == null) {
      return {'total': 0, 'completed': 0};
    }

    try {
      await _loadCompletedQuizIds();
      return {
        'total': _currentTotalQuizzesPerSubject[subjectId] ?? 0,
        'completed': _completedQuizIds.length,
      };
    } catch (e) {
      _logger.e('복습 진행 상황을 가져오는 중 오류 발생: $e');
      return {'total': 0, 'completed': 0};
    }
  }

  void _checkAllQuizzesCompleted() {
    _isAllQuizzesCompleted = _quizzesForReview.isNotEmpty &&
        _completedQuizIds.length >= _quizzesForReview.length;
    notifyListeners();
  }

  // Add this method to update the current total quizzes
  void updateCurrentTotalQuizzes(String subjectId, int newTotal) {
    _currentTotalQuizzesPerSubject[subjectId] = newTotal;
    notifyListeners();
  }
}
