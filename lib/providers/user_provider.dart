import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/constants.dart';
import 'package:nursing_quiz_app_6/services/quiz_service.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  final Logger _logger = Logger();
  final QuizService _quizService = QuizService();
  Map<String, dynamic> _quizData = {};

  User? get user => _user;
  Map<String, dynamic> get quizData => _quizData;

  bool get isAdmin {
    if (_user == null) {
      _logger.i('User is null, not admin');
      return false;
    }
    bool adminStatus = _user!.email == ADMIN_EMAIL;
    _logger.i('Checking admin status for ${_user!.email}: $adminStatus');
    return adminStatus;
  }

  void setUser(User? user) {
    if (_user?.uid != user?.uid) {
      _user = user;
      _logger.i('User state changed: ${user?.email ?? 'No user'}');
      _loadUserQuizData();
      notifyListeners();
    }
  }

  Future<void> _loadUserQuizData() async {
    if (_user != null) {
      try {
        _quizData = await _quizService.getUserQuizData(_user!.uid);
        _logger.i('Loaded user quiz data successfully');
      } catch (e) {
        _logger.e('Error loading user quiz data: $e');
        _quizData = {};
      }
      notifyListeners();
    } else {
      _logger.w('Attempted to load quiz data for null user');
      _quizData = {};
      notifyListeners();
    }
  }

  Future<void> updateQuizData(String quizId, bool isCorrect) async {
    if (_user != null) {
      try {
        await _quizService.updateUserQuizData(_user!.uid, quizId, isCorrect);
        await _loadUserQuizData(); // Reload data after update
        _logger.i(
            'Updated user quiz data for quiz: $quizId, isCorrect: $isCorrect');

        notifyListeners();
      } catch (e) {
        _logger.e('Error updating user quiz data: $e');
      }
    } else {
      _logger.w('Attempted to update quiz data for null user');
    }
  }

  DateTime getNextReviewDate(String quizId) {
    if (_quizData.containsKey(quizId)) {
      return DateTime.parse(_quizData[quizId]['nextReviewDate']);
    }
    return DateTime.now()
        .add(const Duration(minutes: 4320)); // 초기값을 3일(4320분)로 설정
  }

  String getNextReviewTimeString(String quizId) {
    final nextReviewDate = getNextReviewDate(quizId);
    final now = DateTime.now();
    final difference = nextReviewDate.difference(now);

    _logger.i('Calculating next review time for quiz: $quizId');

    if (difference.inDays > 0) {
      return '${difference.inDays}일';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분';
    } else {
      return '1분'; // 1분 미만일 경우 1분으로 표시
    }
  }

  // 추가: 개발 환경에서 사용할 짧은 시간 문자열 반환 메서드
  String getDebugNextReviewTimeString(String quizId) {
    final nextReviewDate = getNextReviewDate(quizId);
    final now = DateTime.now();
    final difference = nextReviewDate.difference(now);

    _logger.i('Calculating debug next review time for quiz: $quizId');

    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분';
    } else {
      return '${difference.inSeconds}초';
    }
  }
}
