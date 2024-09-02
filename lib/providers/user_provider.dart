import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/utils/constants.dart';
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
        await _loadUserData();
      }
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
    await _quizService.saveUserQuizData(_user!.uid);
    _logger.d('사용자 퀴즈 데이터 업데이트 성공');
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
    //  `getNextReviewDate` 메소드를 호출하여 해당 날짜를 가져옴
    final nextReviewDate = getNextReviewDate(subjectId, quizTypeId, quizId);
    //다음 복습 날짜가 설정되지 않았는지 확인
    if (nextReviewDate == null) {
      _logger.w('다음 복습 날짜를 포맷팅할 수 없음: 날짜가 설정되지 않았습니다');
      return null;
    }

    final now = DateTime.now();
    // 다음 복습 날짜와 현재 날짜의 차이를 계산
    final difference = nextReviewDate.difference(now);

    if (difference.isNegative) {
      //차이가 음수인지 확인하여 복습 시간이 경과했는지 판단
      return '복습시간이 경과했습니다';
    }

    return _formatTimeDifference(difference);
  }

  // 서비스로부터 리뷰할 퀴즈를 받는 메소드
  // 복습리스트에 존재하는 것과, 복습카드가 나오는 것을 구분해야 함.
  // getQuizzesForReview의 역할을 명확하게 해야함.
  // Future<List<Quiz>> getQuizzesForReview(
  //     String subjectId, String quizTypeId) async {
  //   if (_user == null) {
  //     _logger.w('Cannot get quizzes for review: No user logged in');
  //     return [];
  //   }
  //   return await _quizService.getQuizzesForReview(
  //       _user!.uid, subjectId, quizTypeId);
  // }

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

  // ---DONE : reset버튼을 누르면, 개별적인 퀴즈ID를 초기화 해야함. 지금은 전체 퀴즈를 초기화함. ---------//
  Future<void> resetUserAnswers(
      String subjectId, String quizTypeId, String quizId) async {
    _logger.i('사용자 퀴즈 데이터 초기화: 과목=$subjectId, 퀴즈유형=$quizTypeId, 퀴즈=$quizId');
    if (_user == null) {
      _logger.w('사용자 ID가 없습니다. 퀴즈 데이터를 초기화할 수 없음');
      return;
    }
    await _quizService.resetUserQuizData(
        _user!.uid, subjectId, quizTypeId, quizId);
    _logger.d('사용자 퀴즈 데이터 초기화 완료');
    // notifyListeners();
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
