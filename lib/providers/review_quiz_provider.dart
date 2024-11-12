import 'package:flutter/foundation.dart';
import 'package:nursing_quiz_app_6/models/quiz.dart';
import 'package:nursing_quiz_app_6/models/subject.dart';
import 'package:nursing_quiz_app_6/services/quiz_service.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

class ReviewQuizzesProvider with ChangeNotifier {
  final QuizService _quizService;
  final Logger _logger;
  final String? userId;

  String? _selectedSubjectId;
  List<Quiz> _quizzesForReview = [];
  bool _isLoading = false;
  List<Subject> _subjects = [];
  Map<String, Set<String>> _subjectTotalReviewQuizIds = {};
  Map<String, Set<String>> _subjectReviewedQuizIds = {};
  DateTime _lastResetDate = DateTime.now();

  ReviewQuizzesProvider(this._quizService, this._logger, this.userId) {
    loadSubjects();
    _loadReviewedQuizIds();
    _loadTotalReviewQuizIds();
  }

  String? get selectedSubjectId => _selectedSubjectId;
  List<Quiz> get quizzesForReview => _quizzesForReview;
  bool get isLoading => _isLoading;
  List<Subject> get subjects => _subjects;

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

  Future<void> loadQuizzesForReview() async {
    if (_selectedSubjectId == null || userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      _quizzesForReview = await _quizService.getQuizzesForReview(
          userId!, _selectedSubjectId!, null);
      _logger.i('복습 카드 ${_quizzesForReview.length}개 로드 완료');
      _logger.d('로드된 퀴즈: ${_quizzesForReview.map((q) => q.id).toList()}');

      // Update _subjectTotalReviewQuizIds
      _subjectTotalReviewQuizIds.putIfAbsent(_selectedSubjectId!, () => {});
      _subjectTotalReviewQuizIds[_selectedSubjectId!]!
          .addAll(_quizzesForReview.map((q) => q.id));
      _saveTotalReviewQuizIds();
    } catch (e) {
      _logger.e('퀴즈 복습 데이터를 불러올 수 없음: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addReviewedQuizId(String quizId) {
    if (_selectedSubjectId == null) return;
    _subjectReviewedQuizIds.putIfAbsent(_selectedSubjectId!, () => {});
    _subjectReviewedQuizIds[_selectedSubjectId!]!.add(quizId);
    _saveReviewedQuizIds();
    notifyListeners();
  }

  Future<void> _loadReviewedQuizIds() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedData = prefs.getString('subject_reviewed_quiz_ids');
    final String? lastResetDateString = prefs.getString('last_reset_date');

    if (storedData != null && lastResetDateString != null) {
      _subjectReviewedQuizIds = Map<String, Set<String>>.from(json
          .decode(storedData)
          .map((key, value) => MapEntry(key, Set<String>.from(value))));
      _lastResetDate = DateTime.parse(lastResetDateString);

      if (!_isSameDay(_lastResetDate, DateTime.now())) {
        _resetReviewedQuizIds();
      }
    }
  }

  Future<void> _saveReviewedQuizIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'subject_reviewed_quiz_ids',
        json.encode(_subjectReviewedQuizIds
            .map((key, value) => MapEntry(key, value.toList()))));
    await prefs.setString('last_reset_date', DateTime.now().toIso8601String());
  }

  Future<void> _loadTotalReviewQuizIds() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storedData = prefs.getString('subject_total_review_quiz_ids');

    if (storedData != null) {
      _subjectTotalReviewQuizIds = Map<String, Set<String>>.from(json
          .decode(storedData)
          .map((key, value) => MapEntry(key, Set<String>.from(value))));
    }
  }

  Future<void> _saveTotalReviewQuizIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'subject_total_review_quiz_ids',
        json.encode(_subjectTotalReviewQuizIds
            .map((key, value) => MapEntry(key, value.toList()))));
  }

  void _resetReviewedQuizIds() {
    _subjectTotalReviewQuizIds.clear();
    _lastResetDate = DateTime.now();
    _saveTotalReviewQuizIds();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String getSubjectName(String? subjectId) {
    if (subjectId == null) return "선택된 과목";
    final subject = _subjects.firstWhere((s) => s.id == subjectId,
        orElse: () => Subject(id: '', name: '알 수 없는 과목'));
    return subject.name;
  }

  // removeQuizFromReview: 현재 화면에 표시되는 퀴즈 목록(_quizzesForReview)에서만 퀴즈를 제거
  // UI 업데이트용
  void removeQuizFromReview(String quizId) {
    _quizzesForReview.removeWhere((quiz) => quiz.id == quizId);
    notifyListeners();

    // Added: Trigger synchronization after removing a quiz from review
    if (userId != null) {
      _quizService.syncUserData(userId!, _quizService.getUserQuizData(userId!));
    }
  }

  Future<Map<String, int>> getReviewProgress(String subjectId) async {
    if (userId == null) {
      return {'total': 0, 'completed': 0, 'remaining': 0};
    }

    try {
      int total = _subjectTotalReviewQuizIds[subjectId]?.length ?? 0;
      int remaining = _quizzesForReview.length;
      int completed = total - remaining;

      // Ensure completed is not negative
      completed = max(0, completed);

      return {'total': total, 'completed': completed, 'remaining': remaining};
    } catch (e) {
      _logger.e('복습 진행 상황을 가져오는 중 오류 발생: $e');
      return {'total': 0, 'completed': 0, 'remaining': 0};
    }
  }

  Future<List<Quiz>> getQuizzesForReview(String subjectId) async {
    if (userId == null) return [];

    try {
      return await _quizService.getQuizzesForReview(userId!, subjectId, null);
    } catch (e) {
      _logger.e('복습할 퀴즈를 가져오는 중 오류 발생: $e');
      return [];
    }
  }
}
