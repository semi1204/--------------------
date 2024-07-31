import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/constants.dart';
import 'package:nursing_quiz_app_6/services/quiz_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nursing_quiz_app_6/utils/anki_algorithm.dart';

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

  Future<void> updateUserQuizData(String quizId, bool isCorrect,
      {Duration? answerTime}) async {
    if (_user == null) {
      _logger.w('Attempted to update quiz data for null user');
      return;
    }

    _logger.i('Updating user quiz data for user: ${_user!.uid}, quiz: $quizId');
    final userData = _quizData;

    if (!userData.containsKey(quizId)) {
      userData[quizId] = {
        'correct': 0,
        'total': 0,
        'nextReviewDate': DateTime.now().toIso8601String(),
        'accuracy': 0.0,
        'interval': 1,
        'easeFactor': 2.5,
        'consecutiveCorrect': 0,
      };
    }

    userData[quizId]['total']++;
    if (isCorrect) {
      userData[quizId]['correct']++;
    }

    userData[quizId]['accuracy'] =
        (userData[quizId]['correct'] / userData[quizId]['total']).toDouble();

    // 수정: Anki 알고리즘 적용
    int? qualityOfRecall;
    if (answerTime != null) {
      qualityOfRecall =
          AnkiAlgorithm.evaluateRecallQuality(answerTime, isCorrect);
    }

    final ankiResult = AnkiAlgorithm.calculateNextReview(
      interval: userData[quizId]['interval'],
      easeFactor: userData[quizId]['easeFactor'],
      consecutiveCorrect: userData[quizId]['consecutiveCorrect'],
      isCorrect: isCorrect,
      qualityOfRecall: qualityOfRecall,
    );

    userData[quizId]['interval'] = ankiResult['interval'];
    userData[quizId]['easeFactor'] = ankiResult['easeFactor'];
    userData[quizId]['consecutiveCorrect'] = ankiResult['consecutiveCorrect'];

    final now = DateTime.now();
    userData[quizId]['nextReviewDate'] =
        now.add(Duration(days: ankiResult['interval'])).toIso8601String();

    _logger.i('Next review interval set to ${ankiResult['interval']} days');

    // Firestore update
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .set({'quizData': userData}, SetOptions(merge: true));

    _quizData = userData;
    notifyListeners();

    _logger.i(
        'User quiz data updated successfully. New accuracy: ${userData[quizId]['accuracy']}, Next review: ${userData[quizId]['nextReviewDate']}');
  }

  DateTime getNextReviewDate(String quizId) {
    if (_quizData.containsKey(quizId)) {
      return DateTime.parse(_quizData[quizId]['nextReviewDate']);
    }
    return DateTime.now()
        .add(const Duration(days: 1)); // Default to 1 day if not found
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
