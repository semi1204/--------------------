// user_provider.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/utils/constants.dart';
import 'package:nursing_quiz_app_6/services/auth_service.dart';
import 'package:nursing_quiz_app_6/services/quiz_service.dart';
import 'package:nursing_quiz_app_6/services/payment_service.dart'; // Add this import
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nursing_quiz_app_6/utils/anki_algorithm.dart';
import 'dart:math' as math;

class UserProvider with ChangeNotifier {
  User? _user;
  bool _isSubscribed = false; // Add this line
  final Logger _logger;
  final AuthService _authService = AuthService();
  final QuizService _quizService = QuizService();
  final PaymentService _paymentService;

  double _targetRetention = 0.9;
  double get targetRetention => _targetRetention;

  void setTargetRetention(double value) {
    _logger.i('Updating target retention from $_targetRetention to $value');
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
      _logger.i('유저가 없습니다, 관리자가 아닙니다');
      return false;
    }
    bool adminStatus = _user!.email == ADMIN_EMAIL;
    _logger.i('유저 ${_user!.email}의 관리자 상태 확인: $adminStatus');
    return adminStatus;
  }

  bool get isSubscribed => _isSubscribed; // Add this getter

  Future<void> setUser(User? user) async {
    _logger.i('유저 이메일: ${user?.email ?? 'No user'}');
    if (_user?.uid != user?.uid) {
      _user = user;
      if (user != null) {
        await _loadUserData();
        await checkAndUpdateSubscriptionStatus(); // Add this line
      } else {
        _isSubscribed = false; // Reset subscription status on logout
      }
      notifyListeners();
    }
  }

  // Add this method
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

  // Firebase의 currentUser를 사용하여 로그인 상태 확인
  Future<bool> isUserLoggedIn() async {
    try {
      final currentUser = _authService.auth.currentUser;
      if (currentUser != null) {
        await setUser(currentUser);
        _logger.i('유저의 로그인 상태 확인 성공: ${currentUser.email}');
        return true;
      } else {
        await setUser(null);
        _logger.i('유저의 로그인 상태 확인 실패');
        return false;
      }
    } catch (e) {
      _logger.e('유저의 로그인 상태 ��인 실패: $e');
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
    _logger.i('유저의 로그아웃 성공');
    notifyListeners();
  }

  // Service에 업데이트된 데이터를 보내는 메소드
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
    if (_user == null) {
      _logger.w('사용자 ID가 없습니다. 퀴즈 데이터를 업데이트할 수 없음');
      return;
    }
    _logger.i(
        '사용자 퀴즈 데이터 업데이트: subjectId=$subjectId, quizTypeId=$quizTypeId, quizId=$quizId, 정답여부=$isCorrect, 이해도 향상여부=$isUnderstandingImproved');
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
    // Removed redundant saveUserQuizData call as it's handled within updateUserQuizData
    // await _quizService.saveUserQuizData(_user!.uid);
    _logger.d('사용자 퀴즈 데이터 업데이트 성공');
    notifyListeners();
  }

  // 복습 리스트(복습리스트엔 복습카드가 존재해야 함)에 퀴즈를 추가하는 메소드
  // --------- 복습리스트에 존재하는 것과, 복습카드가 나오는 것을 구분해야 함.---------//
  Future<void> addToReviewList(
    String subjectId,
    String quizTypeId,
    String quizId,
  ) async {
    if (_user == null) {
      _logger.w('사용자 ID가 없습니다. 복습 리스트에 퀴즈를 추가할 수 없음');
      return;
    }
    await _quizService.addToReviewList(
        _user!.uid, subjectId, quizTypeId, quizId);
    notifyListeners();

    // Added: Trigger synchronization after adding to review list
    await syncUserData();
  }

  // 복습 리스트 Data에서 퀴즈를 제거하는 메소드
  Future<void> removeFromReviewList(
    String subjectId,
    String quizTypeId,
    String quizId,
  ) async {
    if (_user == null) {
      _logger.w('사용자 ID가 없습니다. 복습 리스트에서 퀴즈를 제거할 수 없음');
      return;
    }

    // 복습 리스트에서만 제거하고 복습 관련 데이터만 초기화
    await _quizService.removeFromReviewList(
        _user!.uid, subjectId, quizTypeId, quizId);

    notifyListeners();
    await syncUserData();
  }

  // 복습 리스트에 복습 퀴즈가 존재하는지 확인하는 메소드
  bool isInReviewList(String subjectId, String quizTypeId, String quizId) {
    if (_user == null) {
      _logger.w('사용자 ID가 없습니다. 복습 리스트에 퀴즈가 존재하는지 확인할 수 없음');
      return false;
    }
    return _quizService.isInReviewList(
        _user!.uid, subjectId, quizTypeId, quizId);
  }

  // 복습 리스트에 존재하는 퀴즈의 다음 복습 날짜를 확인하는 메소드
  DateTime? getNextReviewDate(
      String subjectId, String quizTypeId, String quizId,
      {bool isUnderstandingImproved = true}) {
    if (_user == null) {
      _logger.w('사용자 ID가 없습니��. 다음 복습 날짜 확인할 수 없음');
      return null;
    }
    return _quizService.getNextReviewDate(
        _user!.uid, subjectId, quizTypeId, quizId,
        isUnderstandingImproved: isUnderstandingImproved);
  }

  // 복습 리스트에 존재하는 퀴즈의 다음 복습 날짜를 포맷팅하는 메소드
  Map<String, String> formatNextReviewDate(
      String subjectId, String quizTypeId, String quizId) {
    final now = DateTime.now();

    // 알겠음 버튼을 눌렀을 때의 다음 복습 날짜
    final nextReviewDateIfUnderstood = getNextReviewDate(
        subjectId, quizTypeId, quizId,
        isUnderstandingImproved: true);
    // 모르겠음 버튼을 눌렀을 때의 다음 복습 날짜
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
    if (_user == null) {
      _logger.w('Cannot get user quiz data: No user logged in');
      return {};
    }
    return _quizService.getUserQuizData(_user!.uid);
  }

  Future<void> syncUserData() async {
    if (_user == null) {
      _logger.w('Cannot sync user data: No user logged in');
      return;
    }
    try {
      await _quizService.syncUserData(_user!.uid, getUserQuizData());
      _logger.i('사용자 퀴즈 데이터 동기화 성공');
      notifyListeners();
    } catch (e) {
      _logger.e('사용자 퀴즈 데이터 동기화 실패: $e');
      rethrow;
    }
  }

  double getQuizAccuracy(String subjectId, String quizTypeId, String quizId) {
    if (_user == null) {
      _logger.w('Cannot get quiz accuracy: No user logged in');
      return 0.0;
    }
    double accuracy =
        _quizService.getQuizAccuracy(_user!.uid, subjectId, quizTypeId, quizId);
    _logger.d('Quiz accuracy for $quizId: $accuracy');
    return accuracy;
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
    if (_user == null) {
      _logger.w('사용자 ID가 없습니다. 퀴즈 데이터를 동기화할 수 없음');
      return;
    }
    try {
      await _quizService.syncUserData(_user!.uid, getUserQuizData());
      _logger.i('사용자 퀴즈 데이터 동기화 성공');
      notifyListeners();
    } catch (e) {
      _logger.e('사용자 퀴즈 데이터 동기화 실패: $e');
      rethrow;
    }
  }

// calculateNextReviewDate 메소드 수정
  DateTime calculateNextReviewDate(int repetitions, Duration easeFactor) {
    final now = DateTime.now();
    final intervalDays =
        math.min(45, (easeFactor.inMinutes * _targetRetention).round());
    return now.add(Duration(minutes: intervalDays));
  }

  UserProvider({
    required PaymentService paymentService,
    required Logger logger,
  })  : _paymentService = paymentService,
        _logger = logger;

  /// Counts the number of quizzes reviewed on a specific date for a given subject.
  int getReviewedQuizzesCount(String subjectId, DateTime date) {
    if (_user == null) {
      _logger.w('사용자 ID가 없습니다. 복습된 퀴즈 개수를 세는 중 오류 발생');
      return 0;
    }

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

    _logger.d('복습된 퀴즈 개수: $subjectId on ${date.toIso8601String()}: $count');

    return count;
  }

  Future<void> deleteAccount(String password) async {
    try {
      await _authService.deleteAccount(password);
      await signOut();
      _logger.i('User account deleted and signed out');
    } catch (e) {
      _logger.e('Error during account deletion: $e');
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
