import 'package:flutter/foundation.dart';
import 'package:nursing_quiz_app_6/models/quiz.dart';
import 'package:nursing_quiz_app_6/models/subject.dart';
import 'package:nursing_quiz_app_6/services/quiz_service.dart';
import 'package:logger/logger.dart';

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

  ReviewQuizzesProvider(this._quizService, this._logger, this.userId);

  String? get selectedSubjectId => _selectedSubjectId;
  List<Quiz> get quizzesForReview => _quizzesForReview;
  bool get isLoading => _isLoading;
  List<String> get completedQuizIds => _completedQuizIds;
  bool get isAllQuizzesCompleted => _isAllQuizzesCompleted;
  List<Subject> get subjects => _subjects;

  void setSelectedSubjectId(String? subjectId) {
    _selectedSubjectId = subjectId;
    notifyListeners();
  }

  Future<void> loadSubjects() async {
    _subjects = await _quizService.getSubjects();
    notifyListeners();
  }

  Future<void> loadQuizzesForReview() async {
    if (_selectedSubjectId == null || userId == null) {
      _logger.w('과목 또는 사용자 ID가 선택되지 않았습니다.');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      if (userId == null) {
        _logger.w('사용자 ID가 없습니다. 복습 카드를 로드할 수 없음');
        return;
      }

      _logger.d('복습 퀴즈 로드 시작: userId=$userId, subjectId=$_selectedSubjectId');
      _quizzesForReview = await _quizService.getQuizzesForReview(
        userId!,
        _selectedSubjectId!,
        null,
      );

      _logger.i('복습 카드 ${_quizzesForReview.length}개 로드 완료');
      _logger.d('로드된 퀴즈: ${_quizzesForReview.map((q) => q.id).toList()}');

      _checkAllQuizzesCompleted();
    } catch (e) {
      _logger.e('퀴즈 복습 데이터를 불러올 수 없음: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 새로운 메서드: 선택된 과목의 복습 퀴즈를 로드하고 페이지 전환을 준비
  Future<bool> prepareReviewQuizzes(String subjectId) async {
    _selectedSubjectId = subjectId;
    await loadQuizzesForReview();
    return _quizzesForReview.isNotEmpty;
  }

  void _checkAllQuizzesCompleted() {
    _isAllQuizzesCompleted = _quizzesForReview.isEmpty ||
        _quizzesForReview.every((quiz) => _completedQuizIds.contains(quiz.id));
    notifyListeners();
  }

  void addCompletedQuizId(String quizId) {
    _completedQuizIds.add(quizId);
    _checkAllQuizzesCompleted();
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
  }
}
