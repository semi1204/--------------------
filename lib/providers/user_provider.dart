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

  // 수정: updateQuizData 메서드 최적화
  Future<void> updateQuizData(String quizId, bool isCorrect) async {
    if (_user != null) {
      try {
        await _quizService.updateUserQuizData(_user!.uid, quizId, isCorrect);
        await _loadUserQuizData(); // 데이터 업데이트 후 재로드
        _logger.i(
            'Updated user quiz data for quiz: $quizId, isCorrect: $isCorrect');

        // 수정: 로컬 _quizData 업데이트
        if (_quizData.containsKey(quizId)) {
          _quizData[quizId]['total']++;
          if (isCorrect) {
            _quizData[quizId]['correct']++;
          }
          _quizData[quizId]['accuracy'] =
              (_quizData[quizId]['correct'] / _quizData[quizId]['total'])
                  .toDouble();

          // 수정: 새로운 복습 날짜 계산
          final currentReviewDate =
              DateTime.parse(_quizData[quizId]['nextReviewDate']);
          final now = DateTime.now();
          if (isCorrect) {
            final newInterval = currentReviewDate.difference(now) * 2;
            _quizData[quizId]['nextReviewDate'] =
                now.add(newInterval).toIso8601String();
          } else {
            final newInterval = currentReviewDate.difference(now) ~/ 2;
            _quizData[quizId]['nextReviewDate'] =
                now.add(newInterval).toIso8601String();
          }
          _logger.i(
              'New local review date set to: ${_quizData[quizId]['nextReviewDate']}');

          notifyListeners();
        }
      } catch (e) {
        _logger.e('Error updating user quiz data: $e');
      }
    } else {
      _logger.w('Attempted to update quiz data for null user');
    }
  }
}
