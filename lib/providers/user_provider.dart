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
    //notifyListeners();
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
  }

  // 복습 리스트에서 퀴즈를 제거하는 메소드
  // --------- 복습리스트에 존재하는 것과, 복습카드가 나오는 것을 구분해야 함.---------//
  Future<void> removeFromReviewList(
    String subjectId,
    String quizTypeId,
    String quizId,
  ) async {
    if (_user == null) {
      _logger.w('사용자 ID가 없습니다. 복습 리스트에서 퀴즈를 제거할 수 없음');
      return;
    }
    await _quizService.removeFromReviewList(
        _user!.uid, subjectId, quizTypeId, quizId);
    // 복습 데이터 초기화
    await _quizService.resetUserQuizData(
        _user!.uid, subjectId, quizTypeId, quizId);
    notifyListeners();
  }

  // 복습 리스트에 복습 퀴즈가 존재하는지 확인하는 메소드
  // --------- 복습리스트에 존재하는 것과, 복습카드가 나오는 것을 구분해야 함.---------//
  bool isInReviewList(String subjectId, String quizTypeId, String quizId) {
    if (_user == null) {
      _logger.w('사용자 ID가 없습니다. 복습 리스트에 퀴즈가 존재하는지 확인할 수 없음');
      return false;
    }
    return _quizService.isInReviewList(
        _user!.uid, subjectId, quizTypeId, quizId);
  }

  // 복습 리스트에 존재하는 퀴즈의 다음 복습 날짜를 확인하는 메소드
  // --------- 복습리스트에 존재하는 것과, 복습카드가 나오는 것을 구분해야 함.---------//
  DateTime? getNextReviewDate(
      String subjectId, String quizTypeId, String quizId) {
    if (_user == null) {
      _logger.w('사용자 ID가 없습니다. 다음 복습 날짜를 확인할 수 없음');
      return null;
    }
    return _quizService.getNextReviewDate(
        _user!.uid, subjectId, quizTypeId, quizId);
  }

  // 복습 리스트에 존재하는 퀴즈의 다음 복습 날짜를 포맷팅하는 메소드
  String? formatNextReviewDate(
      String subjectId, String quizTypeId, String quizId) {
    final nextReviewDate = getNextReviewDate(subjectId, quizTypeId, quizId);
    if (nextReviewDate == null) {
      _logger.w('다음 복습 날짜를 포맷팅할 수 없음: 날짜가 설정되지 않았습니다');
      return null;
    }

    final now = DateTime.now();
    final difference = nextReviewDate.difference(now);

    if (difference.isNegative) {
      return '복습시간이 경과했습니다';
    }

    return _formatTimeDifference(difference);
  }

  // 서비스로부터 리뷰할 퀴즈를 받는 메소드
  // --------- TODO : 복습리스트에 존재하는 것과, 복습카드가 나오는 것을 구분해야 함.---------//
  // --------- TODO : getQuizzesForReview의 역할을 명확하게 해야함.---------//
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
}
