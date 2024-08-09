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

  // 사용자 퀴즈 데이터를 저장하는 맵
  Map<String, Map<String, Map<String, Map<String, dynamic>>>> _quizData = {};
  // 사용자가 리뷰카드 중 삭제한 퀴즈를 저장하는 집합
  Set<String> _deletedQuizzes = {};
  // 사용자 데이터가 동기화되어야 하는지 여부
  bool _needsSync = false;

  User? get user => _user;
  Map<String, Map<String, Map<String, Map<String, dynamic>>>> get quizData =>
      _quizData;
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
    _logger.i('Setting user: ${user?.email ?? 'No user'}');
    if (_user?.uid != user?.uid) {
      _user = user;
      if (user != null) {
        await loadUserData();
      } else {
        _quizData = {};
        _deletedQuizzes.clear();
      }
      notifyListeners();
    }
  }

  // Firebase의 currentUser를 사용하여 로그인 상태 확인
  Future<bool> isUserLoggedIn() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await setUser(currentUser);
        _logger.i('User is logged in: ${currentUser.email}');
        return true;
      } else {
        await setUser(null);
        _logger.i('User is not logged in');
        return false;
      }
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
  // 유지해야하는 기능 : 사용자 데이터 로드 시 캐시 -> 기 내부 저장소 -> Firestore 순으로 데이터 로드
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
          _quizData = json.decode(cachedData)
              as Map<String, Map<String, Map<String, Map<String, dynamic>>>>;
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

  // 기기 내부 저장소에서 데이터 드
  Future<Map<String, Map<String, Map<String, Map<String, dynamic>>>>?>
      _loadLocalData() async {
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

  // 유지해야하는 기능 : 사용자 답변 가져오기 (QuizPage에서만 사용)
  int? getUserAnswer(String subjectId, String quizTypeId, String quizId) {
    return _quizData[subjectId]?[quizTypeId]?[quizId]?['selectedOptionIndex']
        as int?;
  }

  // 사용자가 선택한 답을 저장하는 메서드
  Future<void> saveUserAnswer(String subjectId, String quizTypeId,
      String quizId, int answerIndex) async {
    _logger.i(
        'Saving user answer: subjectId=$subjectId, quizTypeId=$quizTypeId, quizId=$quizId, answerIndex=$answerIndex');

    _quizData[subjectId] ??= {};
    _quizData[subjectId]![quizTypeId] ??= {};
    _quizData[subjectId]![quizTypeId]![quizId] ??= {};
    _quizData[subjectId]![quizTypeId]![quizId]!['selectedOptionIndex'] =
        answerIndex;

    await _saveQuizData();
    notifyListeners();
    _logger.i('User answer saved successfully');

    _logger.d('Saved quiz data: ${_quizData[subjectId]?[quizTypeId]?[quizId]}');
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

  // 유지해야하는 기능: 기존 구조를 유지하면서 초기화
  Future<void> resetUserAnswers(String subjectId, String quizTypeId,
      {String? quizId}) async {
    if (quizId != null) {
      // 특정 퀴즈 아이디가 제공되었는지 확인
      if (_quizData[subjectId]?[quizTypeId]?[quizId] != null) {
        // 해당 과목과 유형 퀴즈에 대한 데이터 존재 여부 확인
        _quizData[subjectId]![quizTypeId]![quizId] = {
          // 해당 퀴즈의 데이터를 새로운 객체로 초기화
          'nextReviewDate': DateTime.now().toIso8601String(),
          // Reset other fields as needed
          'correct': 0,
          'total': 0,
          'accuracy': 0.0,
          'interval': AnkiAlgorithm.initialInterval,
          'easeFactor': AnkiAlgorithm.defaultEaseFactor,
          'consecutiveCorrect': 0,
          'mistakeCount': 0,
          'markedForReview': false, // 복습리스트에서 제거하는 로직
          'selectedOptionIndex': null,
        };
      }
      _logger.i('퀴즈 데이터 초기화: $quizId');
    } else {
      // Reset all quizzes for the subject and quiz type
      if (_quizData[subjectId]?[quizTypeId] != null) {
        // 특정 과목과 유형에 대한 데이터가 존재 여부 확인
        for (var quizId in _quizData[subjectId]![quizTypeId]!.keys) {
          // 해당 과목과 유형에 속한 퀴즈에 대해 반복
          _quizData[subjectId]![quizTypeId]![quizId] = {
            // 각 퀴즈 ID에 대한 데이터 초기화
            'nextReviewDate': DateTime.now().toIso8601String(),
            // Reset other fields as needed
            'correct': 0,
            'total': 0,
            'accuracy': 0.0,
            'interval': AnkiAlgorithm.initialInterval,
            'easeFactor': AnkiAlgorithm.defaultEaseFactor,
            'consecutiveCorrect': 0,
            'mistakeCount': 0,
            'markedForReview': false, // 복습리스트에서 제거하는 로직
          };
        }
      }
      _logger.i('모든 퀴즈 데이터 초기화: 과목 $subjectId, 퀴즈 유형 $quizTypeId');
    }

    await _saveQuizData();
    notifyListeners();
    _logger.i('User answers reset successfully');
    _logger.d('Updated quiz data: ${_quizData[subjectId]?[quizTypeId]}');
  }

  // 사용자 퀴즈 데이터 업데이트
  // 사용자의 퀴즈 데이터를 업데이트하는 비동기 메서드
  Future<void> updateUserQuizData(
    String subjectId,
    String quizTypeId,
    String quizId,
    bool isCorrect, {
    // 정답여부
    Duration? answerTime, // 답변 시간
    int? selectedOptionIndex, // 선택한 옵션 인덱스
    bool isUnderstandingImproved = false, // 이해도 향상 여부
    bool removeFromReview = false, // 복습 목록에서 제거
  }) async {
    // 로그에 업데이트 정보 기록
    _logger.i(
        '업데이트 된 데이터: subjectId=$subjectId, quizTypeId=$quizTypeId, quizId=$quizId, isCorrect=$isCorrect, removeFromReview=$removeFromReview');

    // 현재 사용자가 없으면 경고 로그를 남기고 종료
    if (_user == null) {
      _logger.w('Attempted to update quiz data for null user');
      return;
    }

    try {
      final quizData =
          _quizData[subjectId]?[quizTypeId]?[quizId] ?? {}; // 퀴즈데이터 가져오기,
      // 없으면 빈 객체를 반환 : 기본값을 가져옴
      int correct = quizData['correct'] ?? 0;
      int total = quizData['total'] ?? 0;
      int consecutiveCorrect = quizData['consecutiveCorrect'] ?? 0; // 연속 정답 개수
      int interval =
          quizData['interval'] ?? AnkiAlgorithm.initialInterval; // 복습 간격
      double easeFactor =
          quizData['easeFactor'] ?? AnkiAlgorithm.defaultEaseFactor; // 쉬움 인수
      int mistakeCount = quizData['mistakeCount'] ?? 0; // 실수 횟수

      total++;
      if (isCorrect) {
        correct++;
      } else {
        mistakeCount++;
      }

      int? qualityOfRecall;
      if (answerTime != null) {
        // 답변 시간이 주어진 경우
        qualityOfRecall = // 기억 품질 평가수행(anki 알고리즘)
            AnkiAlgorithm.evaluateRecallQuality(answerTime, isCorrect);
      }

      final ankiResult = AnkiAlgorithm.calculateNextReview(
        // 다음 복습일정 함수 호출
        interval: interval,
        easeFactor: easeFactor,
        consecutiveCorrect: consecutiveCorrect,
        isCorrect: isCorrect,
        qualityOfRecall: qualityOfRecall,
        mistakeCount: mistakeCount,
        isUnderstandingImproved: isUnderstandingImproved,
      );

      // 학습데이터 업데이트하고 저장
      final now = DateTime.now();
      final nextReviewDate = removeFromReview
          ? null // 복습 목록에서 제거하는 경우 nextReviewDate를 null로 설정
          : now.add(Duration(days: ankiResult['interval'] as int));

      _quizData[subjectId] ??= {};
      _quizData[subjectId]![quizTypeId] ??= {};
      _quizData[subjectId]![quizTypeId]![quizId] = {
        'correct': correct,
        'total': total,
        'accuracy': correct / total,
        'interval': ankiResult['interval'],
        'easeFactor': ankiResult['easeFactor'],
        'consecutiveCorrect': ankiResult['consecutiveCorrect'],
        'nextReviewDate': nextReviewDate?.toIso8601String(),
        'mistakeCount': ankiResult['mistakeCount'],
        'lastAnswered': now.toIso8601String(),
        'selectedOptionIndex': selectedOptionIndex,
        'isUnderstandingImproved': isUnderstandingImproved,
      };

      await _saveQuizData();
      notifyListeners();

      _logger.i('사용자 퀴즈 데이터 업데이트 성공');
      _logger.d(
          'Updated quiz data: ${_quizData[subjectId]![quizTypeId]![quizId]}');
    } catch (e) {
      _logger.e('Error updating user quiz data: $e');
      rethrow;
    }
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
      _logger.i('사용자 데이터가 Firebase와 성공적으로 동기화되었습니다');

      // 로컬 저장소 업데이트
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'user_quiz_data_${_user!.uid}', json.encode(_quizData));
      _logger.i('로컬 저장소의 사용자 데이터가 업데이트되었습니다');

      notifyListeners();
      _logger.i('User data synced successfully with Firebase');
    } catch (e) {
      _logger.e('Error syncing user data with Firebase: $e');
    }
  }

  // 주의 사항:
  // 0으 나누는 상황을 방지해야 함.
  double getQuizAccuracy(String subjectId, String quizTypeId, String quizId) {
    final accuracy =
        _quizData[subjectId]?[quizTypeId]?[quizId]?['accuracy'] as double? ??
            0.0;
    _logger.i(
        'Getting quiz accuracy: subjectId=$subjectId, quizTypeId=$quizTypeId, quizId=$quizId, accuracy=$accuracy');
    return accuracy;
  }

  // 다음 복습 날짜를 가져오는 메서드
  DateTime? getNextReviewDate(
      String subjectId, String quizTypeId, String quizId) {
    final quizData = _quizData[subjectId]?[quizTypeId]?[quizId];
    if (quizData == null || quizData.isEmpty) {
      _logger.w('$quizId에 대한 퀴즈 데이터를 찾을 수 없습니다. null을 반환합니다.');
      return null;
    }

    final nextReviewDateString = quizData['nextReviewDate'];
    if (nextReviewDateString == null) {
      _logger.w('$quizId에 대한 다음 복습 날짜를 찾을 수 없습니다. null을 반환합니다.');
      return null;
    }

    try {
      final nextReviewDate = DateTime.parse(nextReviewDateString);
      // Ensure the next review date is not in the past
      return nextReviewDate.isAfter(DateTime.now())
          ? nextReviewDate
          : DateTime.now();
    } catch (e) {
      _logger.e('다음 복습 날짜 계산 오류: $quizId: $e');
      return null;
    }
  }

  // 다음 복습 시간을 표시하는 메서드
  String getNextReviewTimeString(
      String subjectId, String quizTypeId, String quizId) {
    final quizData = _quizData[subjectId]?[quizTypeId]?[quizId];
    if (quizData == null) {
      _logger.w('No quiz data found for $quizId. Returning "지금"');
      return '지금';
    }

    // getNextReviewDate 메서드를 사용하여 다음 복습 날짜를 가져옴
    final nextReviewDate = getNextReviewDate(subjectId, quizTypeId, quizId);
    final now = DateTime.now();
    final difference = nextReviewDate?.difference(now) ?? Duration.zero;

    _logger.i('Calculating next review time for quiz: $quizId');

    if (kDebugMode) {
      if (difference.inMinutes > 0) {
        return '${difference.inMinutes}분';
      } else {
        return '${difference.inSeconds}초';
      }
    } else {
      if (difference.inDays > 0) {
        return '${difference.inDays}일';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}시간';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}분';
      } else {
        return '${difference.inSeconds}초';
      }
    }
  }

  // Modify the isQuizEligibleForReview method
  bool isQuizEligibleForReview(
      String subjectId, String quizTypeId, String quizId) {
    final quizData = _quizData[subjectId]?[quizTypeId]?[quizId];
    if (quizData == null) return false;

    // Check if the quiz is explicitly marked for review
    if (quizData['markedForReview'] == true) {
      final nextReviewDate =
          DateTime.parse(quizData['nextReviewDate'] as String);
      return DateTime.now().isAfter(nextReviewDate);
    }

    return false;
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
                answerTime: Duration(seconds: quizData['answerTime'] ?? 0),
                isUnderstandingImproved:
                    quizData['isUnderstandingImproved'] ?? false,
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

  Future<void> markQuizForReview(
      String subjectId, String quizTypeId, String quizId) async {
    _logger.i(
        'Marking quiz for review: subjectId=$subjectId, quizTypeId=$quizTypeId, quizId=$quizId');

    try {
      final now = DateTime.now();
      final nextReviewDate =
          now.add(const Duration(minutes: 10)); // 10분 후로 설정 (테스트용)

      _quizData[subjectId] ??= {};
      _quizData[subjectId]![quizTypeId] ??= {};
      _quizData[subjectId]![quizTypeId]![quizId] ??= {};
      _quizData[subjectId]![quizTypeId]![quizId]!['nextReviewDate'] =
          nextReviewDate.toIso8601String();

      await _saveQuizData();
      notifyListeners();
      _logger.i('Quiz marked for review successfully');
      _logger.d(
          'Updated quiz data: ${_quizData[subjectId]![quizTypeId]![quizId]}');
    } catch (e) {
      _logger.e('Error marking quiz for review: $e');
      rethrow;
    }
  }
}
