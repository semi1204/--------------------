import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nursing_quiz_app_6/utils/anki_algorithm.dart';
import 'package:google_sign_in/google_sign_in.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  final Logger _logger = Logger();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Map<String, dynamic> _quizData = {};
  Set<String> _deletedQuizzes = {};
  bool _needsSync = false;

  User? get user => _user;
  Map<String, dynamic> get quizData => _quizData;
  bool get needsSync => _needsSync;

  bool get isAdmin {
    if (_user == null) {
      _logger.i('User is null, not admin');
      return false;
    }
    bool adminStatus = _user!.email == ADMIN_EMAIL;
    _logger.i('Checking admin status for ${_user!.email}: $adminStatus');
    return adminStatus;
  }

  Future<void> setUser(User? user) async {
    if (_user?.uid != user?.uid) {
      _user = user;
      _logger.i('User state changed: ${user?.email ?? 'No user'}');
      if (user != null) {
        // 토큰 저장
        final String? token = await user.getIdToken();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_token', token ?? '');

        await loadUserData(); // 사용자 변경 시 데이터 로드
      } else {
        // 로그아웃 시 토큰 및 데이터 삭제
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_token');
        _quizData = {};
        _deletedQuizzes.clear();
      }
      notifyListeners();
    }
  }

  // 유지되어야하는 기능 : 로그인 상태 확인 시 토큰 유효성 검사
  Future<bool> isUserLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('user_token');

      if (token != null) {
        // 토큰 유효성 검사
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          final String? newToken = await currentUser.getIdToken();
          if (newToken == token) {
            await setUser(currentUser);
            _logger.i('User is logged in: ${currentUser.email}');
            return true;
          }
        }
      }

      // 토큰이 없거나 유효하지 않은 경우
      await setUser(null);
      _logger.i('User is not logged in');
      return false;
    } catch (e) {
      _logger.e('Error checking login status: $e');
      return false;
    }
  }

  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _logger.i('User ${userCredential.user?.email} signed in with email');

      // 로그인 성공 시 토큰 저장
      final String? token = await userCredential.user?.getIdToken();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_token', token);
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      _logger.e('Firebase Auth Error during sign in: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('Error signing in with email: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_token');
      _logger.i('User signed out');
      _quizData.clear();
      _deletedQuizzes.clear();
      notifyListeners();
    } catch (e) {
      _logger.e('Error during sign out: $e');
    }
  }

  Future<void> deleteUserQuizData(
      String userId, String subjectId, String quizTypeId, String quizId) async {
    _logger.i(
        'Deleting user quiz data for user: $userId, subject: $subjectId, quizType: $quizTypeId, quiz: $quizId');
    try {
      // Update local state
      _quizData[subjectId]?[quizTypeId]?.remove(quizId);
      _deletedQuizzes.add(quizId);

      // Update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_quiz_data_$userId', json.encode(_quizData));
      await prefs.setStringList(
          'deleted_quizzes_$userId', _deletedQuizzes.toList());

      notifyListeners();
      _logger.i('User quiz data deleted successfully');
    } catch (e) {
      _logger.e('Error deleting user quiz data: $e');
      rethrow;
    }
  }

  // <<수정 시 주의 사항>>
  // 1. 사용자가 선택한 답은 무조건 기억해야 함.
  // 2. 기억한 답은 초기화 버튼을 누르기 전까지 유지되어야 함.
  // 유지해야하는 기능 : 사용자 데이터 로드 시 캐시 -> 기��� 내부 저장소 -> Firestore 순으로 데이터 로드
  Future<void> loadUserData() async {
    if (_user == null) {
      _logger.w('Attempted to load quiz data for null user');
      _quizData = {};
      return;
    }

    try {
      _logger.i('Loading user data for ${_user!.email}');
      final prefs = await SharedPreferences.getInstance();

      // 1. 캐시에서 데이터 로드 시도
      final cachedData = prefs.getString('user_quiz_data_${_user!.uid}');
      if (cachedData != null) {
        try {
          _quizData = json.decode(cachedData) as Map<String, dynamic>;
          _logger.i('User data loaded from cache');
          _loadDeletedQuizzes(prefs);
          notifyListeners();
          return;
        } catch (e) {
          _logger.w('Failed to parse cached data: $e');
        }
      }

      // 2. 기기 내부 저장소에서 데이터 로드 시도
      final localData = await _loadLocalData();
      if (localData != null) {
        _quizData = localData;
        _logger.i('User data loaded from local storage');
        _loadDeletedQuizzes(prefs);
        notifyListeners();
        return;
      }

      _logger.w('No local data found, initializing empty quiz data');
      _quizData = {};
      _loadDeletedQuizzes(prefs);
      notifyListeners();
    } catch (e) {
      _logger.e('Error loading user data: $e');
      _quizData = {};
      notifyListeners();
    }
  }

  void _loadDeletedQuizzes(SharedPreferences prefs) {
    final deletedQuizzesList =
        prefs.getStringList('deleted_quizzes_${_user!.uid}') ?? [];
    _deletedQuizzes = Set.from(deletedQuizzesList);
    _logger.d('Loaded ${_deletedQuizzes.length} deleted quizzes');
  }

  // 기기 내부 저장소에서 데이터 로드
  Future<Map<String, dynamic>?> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localData = prefs.getString('user_quiz_data_${_user!.uid}');
      if (localData != null) {
        return Map<String, Map<String, Map<String, Map<String, dynamic>>>>.from(
            json.decode(localData));
      }
    } catch (e) {
      _logger.e('Error loading local data: $e');
    }
    return null;
  }

  // 수정시 주의사항
  // 사용자가 선택한 답을 기억하고 있어야 함.
  // QuizPage에서는 사용자가 선택한 답을 기억하고 있어야 하며,
  // incorrectAnswerPage에서는 사용자가 선택한 답을 기억하고 있으면 안됨.
  // Quizpage에서 RadioButton을 초기화하는 유일한 방법은 초기화 버튼을 누르는 것임
  // 초기화 버튼을 누르면, 퀴즈와 관련된 모든 유저 데이터가 초기화 됨.
  Future<void> saveUserAnswer(String subjectId, String quizTypeId,
      String quizId, int answerIndex) async {
    _logger.i(
        'Saving user answer: subjectId=$subjectId, quizTypeId=$quizTypeId, quizId=$quizId, answerIndex=$answerIndex');

    _quizData[subjectId] ??= {};
    _quizData[subjectId]![quizTypeId] ??= {};
    _quizData[subjectId]![quizTypeId]![quizId] ??= {};
    _quizData[subjectId]![quizTypeId]![quizId]!['selectedAnswer'] = answerIndex;

    await _saveQuizData();
    notifyListeners();
    _logger.i('User answer saved successfully');
  }

  // 유지해야하는 기능 : 사용자 답변 가져오기 (QuizPage에서만 사용)
  int? getUserAnswer(String subjectId, String quizTypeId, String quizId) {
    final answer =
        _quizData[subjectId]?[quizTypeId]?[quizId]?['selectedAnswer'] as int?;
    _logger.i(
        'Getting user answer: subjectId=$subjectId, quizTypeId=$quizTypeId, quizId=$quizId, answer=$answer');
    return answer;
  }

  // User마다 quizData를 저장하는 메서드
  // 유지해야하는 기능 : 사용자 데이터를 모든 저장소에 저장
  Future<void> _saveQuizData() async {
    if (_user != null) {
      try {
        _logger.i('Saving quiz data for ${_user!.email}');

        // 1. 캐시에 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'user_quiz_data_${_user!.uid}', json.encode(_quizData));

        // 2. 기기 내부 저장소에 저장
        await prefs.setString(
            'user_quiz_data_local_${_user!.uid}', json.encode(_quizData));

        _logger.i('Quiz data saved successfully to local storage');
      } catch (e) {
        _logger.e('Error saving quiz data: $e');
      }
    } else {
      _logger.w('Attempted to save quiz data for null user');
    }
  }

  Future<void> clearCachedQuizData(
      {String? subjectId, String? quizTypeId, String? quizId}) async {
    _logger.i(
        'Clearing cached quiz data${quizId != null ? " for quiz: $quizId" : ""}');
    if (quizId != null && quizTypeId != null && subjectId != null) {
      _quizData[subjectId]?[quizTypeId]?.remove(quizId);
    } else if (quizTypeId != null && subjectId != null) {
      _quizData[subjectId]?.remove(quizTypeId);
    } else if (subjectId != null) {
      _quizData.remove(subjectId);
    } else {
      _quizData.clear();
    }

    await _saveQuizData();
    notifyListeners();
    _logger.i('Cached quiz data cleared');
  }

  // 유지해야하는 기능: 사용자 답변 초기화 시 모든 저장소에서 삭제
  Future<void> resetUserAnswers(String subjectId, String quizTypeId,
      {String? quizId}) async {
    if (quizId != null) {
      _quizData[subjectId]?[quizTypeId]?[quizId]?.remove('selectedAnswer');
      _quizData[subjectId]?[quizTypeId]?[quizId]?.remove('selectedOptionIndex');
      _logger.i('Reset user answer for quiz: $quizId');
    } else {
      _quizData[subjectId]?[quizTypeId]?.forEach((quizId, quizData) {
        quizData.remove('selectedAnswer');
        quizData.remove('selectedOptionIndex');
      });
      _logger.i(
          'Reset all user answers for subject: $subjectId, quizType: $quizTypeId');
    }
    await _saveQuizData();
    notifyListeners();
  }

  Future<void> updateUserQuizData(
      String subjectId, String quizTypeId, String quizId, bool isCorrect,
      {Duration? answerTime,
      int? selectedOptionIndex,
      int mistakeCount = 0}) async {
    if (_user == null) {
      _logger.w('Attempted to update quiz data for null user');
      return;
    }

    _logger.i(
        'Updating user quiz data: subjectId=$subjectId, quizTypeId=$quizTypeId, quizId=$quizId, isCorrect=$isCorrect, selectedOptionIndex=$selectedOptionIndex');

    var quizData = _quizData
        .putIfAbsent(subjectId, () => {})
        .putIfAbsent(quizTypeId, () => {})
        .putIfAbsent(
            quizId,
            () => {
                  'correct': 0,
                  'total': 0,
                  'nextReviewDate': DateTime.now().toIso8601String(),
                  'accuracy': 0.0,
                  'interval': 1,
                  'easeFactor': 2.5,
                  'consecutiveCorrect': 0,
                  'selectedOptionIndex': null, // 선택한 옵션 인덱스 저장
                  'mistakeCount': 0,
                }); // 퀴�� 데이터 초기화

    quizData['total'] = (quizData['total'] as int? ?? 0) + 1; // 총 퀴즈 수 증가
    if (isCorrect) {
      quizData['correct'] = (quizData['correct'] as int? ?? 0) + 1; // 정답 수 증가
    }

    quizData['accuracy'] =
        (quizData['correct'] as int) / (quizData['total'] as int); // 정확도 계산
    quizData['selectedOptionIndex'] =
        selectedOptionIndex; // 추가: 선택한 옵션 인덱스 업데이트
    quizData['mistakeCount'] = mistakeCount; // 실수 횟수 업데이트

    int? qualityOfRecall;
    if (answerTime != null) {
      qualityOfRecall = AnkiAlgorithm.evaluateRecallQuality(
          answerTime, isCorrect); // 기억의 질 평가
    }

    final ankiResult = AnkiAlgorithm.calculateNextReview(
      interval: quizData['interval'] as int? ?? 1,
      easeFactor: quizData['easeFactor'] as double? ?? 2.5,
      consecutiveCorrect: quizData['consecutiveCorrect'] as int? ?? 0,
      isCorrect: isCorrect,
      qualityOfRecall: qualityOfRecall,
      mistakeCount: mistakeCount,
    ); // anki 알고리즘 결과 계산

    quizData['interval'] = (ankiResult['interval'] as num).toInt(); // 간격 업데이트
    quizData['easeFactor'] = ankiResult['easeFactor'] as double; // 용이성 계수 업데이트
    quizData['consecutiveCorrect'] =
        (ankiResult['consecutiveCorrect'] as num).toInt(); // 연속 정답 횟수 업데이트

    final now = DateTime.now();
    quizData['nextReviewDate'] = now
        .add(Duration(days: ankiResult['interval'] as int))
        .toIso8601String(); // 다음 복습 날짜 설정

    _logger.i(
        'User quiz data updated. New accuracy: ${quizData['accuracy']}, Next review: ${quizData['nextReviewDate']}');

    await _saveQuizData(); // 퀴즈 데이터 저장
    _needsSync = true;
    notifyListeners(); // 리스너들에게 알림
  }

  // 특정 퀴즈의 실수 횟수를 가져오는 메소드
  int getQuizMistakeCount(String subjectId, String quizTypeId, String quizId) {
    return _quizData[subjectId]?[quizTypeId]?[quizId]?['mistakeCount']
            as int? ??
        0;
  }

  // 사용자의 데이터를 Firebase에 동기화하는 메소드
  Future<void> syncUserData() async {
    if (_user == null || !_needsSync) {
      _logger.w('No need to sync user data');
      return;
    }

    _logger.i('Syncing user data with Firebase');
    try {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'quizData': _quizData,
      }, SetOptions(merge: true));
      _needsSync = false;
      notifyListeners();
      _logger.i('User data synced successfully with Firebase');
    } catch (e) {
      _logger.e('Error syncing user data with Firebase: $e');
    }
  }

  // 주의 사항:
  // 0으로 나누는 상황을 방지해야 함.
  double getQuizAccuracy(String subjectId, String quizTypeId, String quizId) {
    final accuracy =
        _quizData[subjectId]?[quizTypeId]?[quizId]?['accuracy'] as double? ??
            0.0;
    _logger.i(
        'Getting quiz accuracy: subjectId=$subjectId, quizTypeId=$quizTypeId, quizId=$quizId, accuracy=$accuracy');
    return accuracy;
  }

  DateTime getNextReviewDate(
      String subjectId, String quizTypeId, String quizId) {
    final nextReviewDateString = _quizData[subjectId]?[quizTypeId]?[quizId]
        ?['nextReviewDate'] as String?;
    if (nextReviewDateString != null) {
      return DateTime.parse(nextReviewDateString);
    }
    return DateTime.now().add(const Duration(days: 1));
  }

  String getNextReviewTimeString(
      String subjectId, String quizTypeId, String quizId) {
    final nextReviewDate = getNextReviewDate(subjectId, quizTypeId, quizId);
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

  // Add this method for offline support
  Future<void> syncOfflineData() async {
    _logger.i('Syncing offline data');
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineData = prefs.getString('offline_quiz_data');
      if (offlineData != null) {
        final decodedData = json.decode(offlineData) as Map<String, dynamic>;
        for (final subjectId in decodedData.keys) {
          for (final quizTypeId in decodedData[subjectId].keys) {
            for (final quizId in decodedData[subjectId][quizTypeId].keys) {
              final quizData = decodedData[subjectId][quizTypeId][quizId];
              await updateUserQuizData(
                subjectId,
                quizTypeId,
                quizId,
                quizData['isCorrect'],
                selectedOptionIndex: quizData['selectedOptionIndex'],
                mistakeCount: quizData['mistakeCount'],
              );
            }
          }
        }
        await prefs.remove('offline_quiz_data');
        _logger.i('Offline data synced successfully');
      }
    } catch (e) {
      _logger.e('Error syncing offline data: $e');
    }
  }

  String getDebugNextReviewTimeString(
      String subjectId, String quizTypeId, String quizId) {
    final nextReviewDate = getNextReviewDate(subjectId, quizTypeId, quizId);
    final now = DateTime.now();
    final difference = nextReviewDate.difference(now);

    _logger.i('Calculating debug next review time for quiz: $quizId');

    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분';
    } else {
      return '${difference.inSeconds}초';
    }
  }

  Future<void> markQuizForReview(
      String subjectId, String quizTypeId, String quizId) async {
    _logger.i('Marking quiz for review: $quizId');
    if (_user == null) {
      _logger.w('Attempted to mark quiz for review for null user');
      return;
    }

    try {
      final quizData = _quizData[subjectId]?[quizTypeId]?[quizId] ?? {};
      quizData['markedForReview'] = true;
      quizData['markedForReviewAt'] = DateTime.now().toIso8601String();

      // Update local state
      _quizData[subjectId] ??= {};
      _quizData[subjectId]![quizTypeId] ??= {};
      _quizData[subjectId]![quizTypeId]![quizId] = quizData;

      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'quizData': {
          subjectId: {
            quizTypeId: {
              quizId: quizData,
            },
          },
        },
      }, SetOptions(merge: true));

      // Update SharedPreferences
      await _saveQuizData();

      _logger.i('Quiz marked for review successfully');
      notifyListeners();
    } catch (e) {
      _logger.e('Error marking quiz for review: $e');
    }
  }

  List<String> getQuizzesMarkedForReview(String subjectId, String quizTypeId) {
    final quizzes = _quizData[subjectId]?[quizTypeId] ?? {};
    return quizzes.entries
        .where((entry) => entry.value['markedForReview'] == true)
        .map((entry) => entry.key)
        .toList();
  }

  authStateChanges() {}
}
