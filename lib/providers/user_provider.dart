import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/constants.dart';
import '../models/quiz.dart';
import 'package:nursing_quiz_app_6/services/auth_service.dart';
import 'package:nursing_quiz_app_6/services/quiz_service.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  final Logger _logger = Logger();
  final AuthService _authService = AuthService();
  final QuizService _quizService = QuizService();

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

  Future<void> setUser(User? user) async {
    _logger.i('유저 이메일: ${user?.email ?? 'No user'}');
    if (_user?.uid != user?.uid) {
      _user = user;
      if (user != null) {
        await _quizService.loadUserQuizData(user.uid);
      }
      notifyListeners();
    }
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
      _logger.e('유저의 로그인 상태 확인 실패: $e');
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

  Future<void> signOut() async {
    await _authService.signOut();
    await setUser(null);
    _logger.i('유저의 로그아웃 성공');
    notifyListeners();
  }

  // service에 업데이트된 데이터를 보내는 메소드
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
      _logger.w('Cannot update quiz data: No user logged in');
      return;
    }
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

  // 서비스로부터 리뷰할 퀴즈를 받는 메소드
  Future<List<Quiz>> getQuizzesForReview(
      String subjectId, String quizTypeId) async {
    if (_user == null) {
      _logger.w('Cannot get quizzes for review: No user logged in');
      return [];
    }
    return await _quizService.getQuizzesForReview(
        _user!.uid, subjectId, quizTypeId);
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
    await _quizService.syncUserData(_user!.uid, getUserQuizData());
  }

  // 복습일자를 날짜로 변환한 메소드
  DateTime? getNextReviewDate(
      String subjectId, String quizTypeId, String quizId) {
    if (_user == null) {
      _logger.w('퀴즈 복습 날짜를 가져올 수 없음: 로그인된 사용자가 없습니다');
      return null;
    }

    final userData = _quizService.getUserQuizData(_user!.uid);
    final quizUserData = userData[subjectId]?[quizTypeId]?[quizId];

    if (quizUserData != null && quizUserData is Map<String, dynamic>) {
      final nextReviewDate = quizUserData['nextReviewDate'];
      if (nextReviewDate != null) {
        if (nextReviewDate is DateTime) {
          return nextReviewDate; // DateTime 객체를 반환
        } else if (nextReviewDate is String) {
          return DateTime.tryParse(nextReviewDate); // 문자열을 DateTime으로 변환
        }
      }
    }

    _logger.w('퀴즈 복습 날짜를 가져올 수 없음: 데이터가 없거나 잘못된 형식입니다');
    return null;
  }

  // 복습일자를 수열로 변환한 메소드(snackbar용)
  String? formatNextReviewDate(
      String subjectId, String quizTypeId, String quizId) {
    final nextReviewDate = getNextReviewDate(subjectId, quizTypeId, quizId);
    if (nextReviewDate == null) {
      _logger.w('퀴즈 복습 날짜를 가져올 수 없음: 날짜가 설정되지 않았습니다');
      return null;
    }

    final now = DateTime.now();
    final difference = nextReviewDate.difference(now);

    if (difference.isNegative) {
      return '복습시간이 경과했습니다';
    }

    return _formatTimeDifference(difference);
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

  Future<void> resetUserAnswers(String subjectId, String quizTypeId,
      {required String quizId}) async {
    if (_user == null) {
      _logger.w('Cannot reset quiz data: No user logged in');
      return;
    }
    await _quizService.resetUserQuizData(
        _user!.uid, subjectId, quizTypeId, quizId);
    notifyListeners();
  }

  double getQuizAccuracy(String subjectId, String quizTypeId, String quizId) {
    if (_user == null) {
      _logger.w('Cannot get quiz accuracy: No user logged in');
      return 0.0;
    }
    return _quizService.getQuizAccuracy(
        _user!.uid, subjectId, quizTypeId, quizId);
  }
}
