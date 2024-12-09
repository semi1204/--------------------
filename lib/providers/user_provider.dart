// user_provider.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nursing_quiz_app_6/utils/constants.dart';
import 'package:nursing_quiz_app_6/services/auth_service.dart';
import 'package:nursing_quiz_app_6/services/quiz_service.dart';
import 'package:nursing_quiz_app_6/services/payment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nursing_quiz_app_6/utils/anki_algorithm.dart';
import 'dart:math' as math;

class UserProvider with ChangeNotifier {
  User? _user;
  bool _isSubscribed = false;
  final AuthService _authService = AuthService();
  final QuizService _quizService = QuizService();
  final PaymentService _paymentService;

  double _targetRetention = 0.9;
  double get targetRetention => _targetRetention;

  void setTargetRetention(double value) {
    _targetRetention = value;
    AnkiAlgorithm.targetRetention = value;
    notifyListeners();
    _saveTargetRetention();
  }

  void _loadTargetRetention() async {
    final prefs = await SharedPreferences.getInstance();
    _targetRetention = prefs.getDouble('targetRetention') ?? 0.9;
    AnkiAlgorithm.targetRetention = _targetRetention;
    notifyListeners();
  }

  void _saveTargetRetention() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('targetRetention', _targetRetention);
  }

  Future<bool> isEmailVerified() async {
    return await _authService.isEmailVerified();
  }

  Future<void> sendEmailVerification() async {
    await _authService.sendEmailVerification();
  }

  User? get user => _user;

  bool get isAdmin {
    if (_user == null) {
      return false;
    }
    return _user!.email == ADMIN_EMAIL;
  }

  bool get isSubscribed => _isSubscribed;

  Future<void> setUser(User? user) async {
    if (_user?.uid != user?.uid) {
      _user = user;
      if (user != null) {
        await _loadUserData();
        await checkAndUpdateSubscriptionStatus();
      } else {
        _isSubscribed = false;
      }
      notifyListeners();
    }
  }

  Future<void> checkAndUpdateSubscriptionStatus() async {
    if (_user != null) {
      _isSubscribed = await _paymentService.checkSubscriptionStatus();
      notifyListeners();
    }
  }

  Future<void> _loadUserData() async {
    if (_user == null) return;
    await _quizService.loadUserQuizData(_user!.uid);
  }

  Future<bool> isUserLoggedIn() async {
    try {
      final currentUser = _authService.auth.currentUser;
      if (currentUser != null) {
        await setUser(currentUser);
        return true;
      } else {
        await setUser(null);
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    final user = await _authService.signInWithEmailAndPassword(email, password);
    if (user != null) {
      await setUser(user);
    }
    return user;
  }

  Future<User?> signInWithApple() async {
    final user = await _authService.signInWithApple();
    if (user != null) {
      await setUser(user);
    }
    return user;
  }

  Future<void> signOut() async {
    await _authService.signOut();
    await setUser(null);
    notifyListeners();
  }

  Future<void> updateUserQuizData(
    String subjectId,
    String quizTypeId,
    String quizId,
    bool isCorrect, {
    Duration? answerTime,
    int? selectedOptionIndex,
    bool isUnderstandingImproved = false,
    bool? toggleReviewStatus,
  }) async {
    if (_user == null) return;

    await _quizService.updateUserQuizData(
      _user!.uid,
      subjectId,
      quizTypeId,
      quizId,
      isCorrect,
      answerTime: answerTime,
      selectedOptionIndex: selectedOptionIndex,
      isUnderstandingImproved: isUnderstandingImproved,
      toggleReviewStatus: toggleReviewStatus,
    );
    notifyListeners();
  }

  Future<void> addToReviewList(
    String subjectId,
    String quizTypeId,
    String quizId,
  ) async {
    if (_user == null) return;

    await _quizService.addToReviewList(
        _user!.uid, subjectId, quizTypeId, quizId);
    notifyListeners();
    await syncUserData();
  }

  Future<void> removeFromReviewList(
    String subjectId,
    String quizTypeId,
    String quizId,
  ) async {
    if (_user == null) return;

    await _quizService.removeFromReviewList(
        _user!.uid, subjectId, quizTypeId, quizId);
    notifyListeners();
    await syncUserData();
  }

  bool isInReviewList(String subjectId, String quizTypeId, String quizId) {
    if (_user == null) return false;
    return _quizService.isInReviewList(
        _user!.uid, subjectId, quizTypeId, quizId);
  }

  DateTime? getNextReviewDate(
      String subjectId, String quizTypeId, String quizId,
      {bool isUnderstandingImproved = true}) {
    if (_user == null) return null;
    return _quizService.getNextReviewDate(
        _user!.uid, subjectId, quizTypeId, quizId,
        isUnderstandingImproved: isUnderstandingImproved);
  }

  Map<String, String> formatNextReviewDate(
      String subjectId, String quizTypeId, String quizId) {
    final now = DateTime.now();

    final nextReviewDateIfUnderstood = getNextReviewDate(
        subjectId, quizTypeId, quizId,
        isUnderstandingImproved: true);
    final nextReviewDateIfNotUnderstood = getNextReviewDate(
        subjectId, quizTypeId, quizId,
        isUnderstandingImproved: false);

    String formatDate(DateTime? date) {
      if (date == null) {
        return '날짜가 설정되지 않았습니다';
      }
      final difference = date.difference(now);
      if (difference.isNegative) {
        return '복습시간이 경과했습니다';
      }
      return _formatTimeDifference(difference);
    }

    return {
      'understood': formatDate(nextReviewDateIfUnderstood),
      'notUnderstood': formatDate(nextReviewDateIfNotUnderstood),
    };
  }

  Map<String, dynamic> getUserQuizData() {
    if (_user == null) return {};
    return _quizService.getUserQuizData(_user!.uid);
  }

  Future<void> syncUserData() async {
    if (_user == null) return;
    try {
      await _quizService.syncUserData(_user!.uid, getUserQuizData());
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  double getQuizAccuracy(String subjectId, String quizTypeId, String quizId) {
    if (_user == null) return 0.0;
    return _quizService.getQuizAccuracy(
        _user!.uid, subjectId, quizTypeId, quizId);
  }

  String _formatTimeDifference(Duration difference) {
    if (difference.inDays > 0) {
      return '${difference.inDays}일 후';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 후';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 후';
    } else {
      return '${difference.inSeconds}초 후';
    }
  }

  Future<void> syncUserQuizData() async {
    if (_user == null) return;
    try {
      await _quizService.syncUserData(_user!.uid, getUserQuizData());
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  DateTime calculateNextReviewDate(int repetitions, Duration easeFactor) {
    final now = DateTime.now();
    final intervalDays =
        math.min(45, (easeFactor.inMinutes * _targetRetention).round());
    return now.add(Duration(minutes: intervalDays));
  }

  UserProvider({
    required PaymentService paymentService,
  }) : _paymentService = paymentService;

  int getReviewedQuizzesCount(String subjectId, DateTime date) {
    if (_user == null) return 0;

    int count = 0;
    final userData = _quizService.getUserQuizData(_user!.uid);
    final subjectData = userData[subjectId] as Map<String, dynamic>?;

    if (subjectData != null) {
      subjectData.forEach((quizTypeId, quizzes) {
        (quizzes as Map<String, dynamic>).forEach((quizId, quizData) {
          final lastAnswered = DateTime.parse(quizData['lastAnswered']);
          if (lastAnswered.year == date.year &&
              lastAnswered.month == date.month &&
              lastAnswered.day == date.day) {
            count++;
          }
        });
      });
    }

    return count;
  }

  Future<void> deleteAccount(String password) async {
    try {
      await _authService.deleteAccount(password);
      await signOut();
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> canAttemptQuiz() async {
    if (_user == null) return false;
    return await _paymentService.canAttemptQuiz();
  }

  Future<void> incrementQuizAttempt() async {
    if (_user == null) return;
    await _paymentService.incrementQuizAttempt();
  }
}
