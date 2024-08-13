import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/constants.dart';
import 'package:nursing_quiz_app_6/models/quiz_user_data.dart';
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

  // 사용자 퀴즈데이터를 저장하는 맵
  Map<String, Map<String, Map<String, QuizUserData>>> _quizData = {};
  // 사용자가 삭제한 퀴즈데이터를 저장하는 셋
  Set<String> _deletedQuizzes = {};
  // 사용자 퀴즈데이터가 오프라인에서 동기화 되었는지 확인하는 변수
  bool _needsSync = false;

  User? get user => _user;
  Map<String, Map<String, Map<String, QuizUserData>>> get quizData => _quizData;
  bool get needsSync => _needsSync;

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
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _logger.i('유저 ${userCredential.user?.email}가 이메일로 로그인 성공');

      // 로그인 성공 시 토큰 저장
      final String? token = await userCredential.user?.getIdToken();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_token', token);
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      _logger.e('유저의 로그인 실패: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      _logger.e('유저의 로그인 실패: $e');
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
      _logger.i('유저의 로그아웃 성공');
      _quizData.clear();
      _deletedQuizzes.clear();
      notifyListeners();
    } catch (e) {
      _logger.e('유저의 로그아웃 실패: $e');
    }
  }

  Future<void> deleteUserQuizData(
      String subjectId, String quizTypeId, String quizId) async {
    _logger.i(
        '유저 ${_user!.uid}의 퀴즈 데이터 삭제: 주제: $subjectId, 퀴즈 타입: $quizTypeId, 퀴즈: $quizId');
    try {
      // Update local state
      _quizData[subjectId]?[quizTypeId]?.remove(quizId);
      _deletedQuizzes.add(quizId);

      // Update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'user_quiz_data_${_user!.uid}', json.encode(_quizData));
      await prefs.setStringList(
          'deleted_quizzes_${_user!.uid}', _deletedQuizzes.toList());

      notifyListeners();
      _logger.i('유저의 퀴즈데이터 삭제 성공');
    } catch (e) {
      _logger.e('유저의 퀴즈데이터 삭제 실패: $e');
      rethrow;
    }
  }

  // <<수정 시 주의 사항>>
  // 1. 사용자가 선택한 답은 무조건 기억해야 함.
  // 2. 기억한 답은 초기화 버튼을 누르기 전까지 유지되어야 함.
  // 유지해야하는 기능 : 사용자 데이터 로드 시 캐시 -> 기기 내부 저장소
  // --------- TODO : updateUserQuizData 메서드 호출과 차이점 파악 후 updateUserQuizData 메서드 호출로 변경가능한지 확인 ---------//
  Future<void> loadUserData() async {
    if (_user == null) {
      _logger.w('유저의 퀴즈데이터 로드 실패: 유저가 없습니다');
      _quizData = {};
      return;
    }

    try {
      _logger.i('유저${_user!.email}의 퀴즈데이터 로드 시작');
      final prefs = await SharedPreferences.getInstance();

      // 1. 캐시에서 데이터 로드 시도
      final cachedData = prefs.getString('user_quiz_data_${_user!.uid}');
      if (cachedData != null) {
        try {
          final decodedData = json.decode(cachedData) as Map<String, dynamic>;
          _quizData = _convertToQuizUserDataMap(decodedData);
          _logger.i('유저${_user!.email}의 퀴즈데이터 캐시 로드 성공');
          _loadDeletedQuizzes(prefs);
          notifyListeners();
          return;
        } catch (e) {
          _logger.w('유저${_user!.email}의 퀴즈데이터 캐시 로드 실패: $e');
        }
      }

      // 2. 기기 내부 저장소에서 데이터 로드 시도
      final localData = await _loadLocalData();
      if (localData != null) {
        _quizData = localData;
        _logger.i('유저${_user!.email}의 퀴즈데이터가 로컬 저장소에서 로드되었습니다');
        _loadDeletedQuizzes(prefs);
        notifyListeners();
        return;
      }

      _logger.w('로컬 데이터를 찾을 수 없습니다, 빈 퀴즈데이터를 초기화합니다');
      _quizData = {}; // 둘 다 없으면 빈 _quizData를 초기화
      _loadDeletedQuizzes(prefs);
      notifyListeners();
    } catch (e) {
      _logger.e('유저${_user!.email}의 퀴즈데이터 로드 실패: $e');
      _quizData = {};
      notifyListeners();
    }
  }

  Map<String, Map<String, Map<String, QuizUserData>>> _convertToQuizUserDataMap(
      Map<String, dynamic> data) {
    return data.map((subjectId, subjectData) {
      return MapEntry(
        subjectId,
        (subjectData as Map<String, dynamic>).map((quizTypeId, quizTypeData) {
          return MapEntry(
            quizTypeId,
            (quizTypeData as Map<String, dynamic>).map((quizId, quizData) {
              return MapEntry(quizId,
                  QuizUserData.fromJson(quizData as Map<String, dynamic>));
            }),
          );
        }),
      );
    });
  }

  // TODO : 각 유저의 삭제된 데이터가 필요한지 확인해봐야함
  void _loadDeletedQuizzes(SharedPreferences prefs) {
    final deletedQuizzesList =
        prefs.getStringList('deleted_quizzes_${_user!.uid}') ?? [];
    _deletedQuizzes = Set.from(deletedQuizzesList);
    _logger.d('유저${_user!.email}의 삭제된 퀴즈 로드 성공: ${_deletedQuizzes.length}개');
  }

  Future<Map<String, Map<String, Map<String, QuizUserData>>>?>
      _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localData = prefs.getString('user_quiz_data_${_user!.uid}');
      if (localData != null) {
        final decodedData = json.decode(localData) as Map<String, dynamic>;
        _logger.d('유저${_user!.email}의 퀴즈데이터 로컬 데이터 디코딩 성공');
        return _convertToQuizUserDataMap(decodedData);
      }
    } catch (e) {
      _logger.e('유저의 퀴즈데이터 로드 실패: $e');
    }
    return null;
  }

  // 유지해야하는 기능 : 사용자 답변 가져오기 (QuizPage에서만 사용)
  int? getUserAnswer(String subjectId, String quizTypeId, String quizId) {
    return _quizData[subjectId]?[quizTypeId]?[quizId]?.selectedOptionIndex;
  }

  // 사용자가 선택한 답을 저장하는 메서드
  Future<void> saveUserAnswer(String subjectId, String quizTypeId,
      String quizId, int answerIndex) async {
    _logger.i(
        'Saving user answer: subjectId=$subjectId, quizTypeId=$quizTypeId, quizId=$quizId, answerIndex=$answerIndex');

    _quizData[subjectId] ??= {};
    _quizData[subjectId]![quizTypeId] ??= {};
    _quizData[subjectId]![quizTypeId]![quizId] ??= QuizUserData(
      nextReviewDate: DateTime.now(),
      lastAnswered: DateTime.now(),
    );
    _quizData[subjectId]![quizTypeId]![quizId]!.selectedOptionIndex =
        answerIndex;

    await _saveQuizData();
    notifyListeners();
    _logger.i('User answer saved successfully');
    _logger.d(
        '유저${_user!.email}의 퀴즈데이터 저장 성공: ${_quizData[subjectId]?[quizTypeId]?[quizId]?.toJson()}');
  }

  // User마다 quizData를 저장하는 메서드
  // 유지해야하는 기능 : 사용자 데이터를 모든 저장소에 저장
  Future<void> _saveQuizData() async {
    if (_user != null) {
      try {
        _logger.i('Saving quiz data for ${_user!.email}');

        // 1. 캐시에 저장
        final prefs = await SharedPreferences.getInstance();
        // 2. 로컬 저장소에 저장
        await prefs.setString(
            'user_quiz_data_${_user!.uid}', json.encode(_quizData));
        await prefs.setString(
            'user_local_quiz_data_${_user!.uid}', json.encode(_quizData));

        _logger.i('유저${_user!.uid}의 퀴즈데이터가 로컬 저장소에 성공적으로 저장되었습니다');
      } catch (e) {
        _logger.e('유저${_user!.uid}의 퀴즈데이터 저장 실패: $e');
      }
    } else {
      _logger.w('유저${_user!.uid}의 퀴즈데이터 저장 실패: 유저가 없습니다');
    }
  }

  Future<void> clearCachedQuizData(
      {String? subjectId, String? quizTypeId, String? quizId}) async {
    _logger.i(
        '유저${_user!.uid}의 퀴즈데이터 캐시 삭제${quizId != null ? " for quiz: $quizId" : ""}');
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
  // --------- TODO : 초기화 된 데이터가 복습카드에 적용되는지 확인 ---------//
  Future<void> resetUserAnswers(String subjectId, String quizTypeId,
      {String? quizId}) async {
    if (quizId != null) {
      // 특정 퀴즈 아이디가 제공되었는지 확인
      if (_quizData[subjectId]?[quizTypeId]?[quizId] != null) {
        _quizData[subjectId]![quizTypeId]![quizId] = QuizUserData(
          nextReviewDate: DateTime.now(),
          lastAnswered: DateTime.now(),
        );
      }
      _logger.i('퀴즈 데이터 초기화: $quizId');
    } else {
      if (_quizData[subjectId]?[quizTypeId] != null) {
        // 특정 과목과 유형에 대한 데이터가 존재 여부 확인
        for (var quizId in _quizData[subjectId]![quizTypeId]!.keys) {
          _quizData[subjectId]![quizTypeId]![quizId] = QuizUserData(
            nextReviewDate: DateTime.now(),
            lastAnswered: DateTime.now(),
          );
        }
      }
      _logger
          .i('유저${_user!.email}의 퀴즈데이터 초기화: 과목 $subjectId, 퀴즈 유형 $quizTypeId');
    }

    await _saveQuizData();
    notifyListeners();
    _logger.i('유저${_user!.uid}의 퀴즈데이터 초기화 성공');
    _logger.d('유저${_user!.uid}의 퀴즈데이터: ${_quizData[subjectId]?[quizTypeId]}');
  }

  // 사용자 퀴즈 데이터 업데이트
  // 사용자의 퀴즈 데이터를 업데이트하는 비동기 메서드
  // --------- TODO : 복습로직에 적용되는지 확인 ---------//
  // ---- TODO : reviewCard가 toggleReviewStatus 변수를 확인하고, 복습로직에 적용 ---------//
  // --------- TODO : 데이터를 덮어쓸 때 이전 데이터를 고려 후, (복습로직에)삭제하고 덮어쓸 수 있는 아이디어 필요(서버 호출비용 절감목적) ---------//
  Future<void> updateUserQuizData(
    String subjectId,
    String quizTypeId,
    String quizId,
    bool isCorrect, {
    Duration? answerTime, // 답변 시간
    int? selectedOptionIndex, // 선택한 옵션 인덱스
    bool isUnderstandingImproved = false, // 이해도 향상 여부
    bool? toggleReviewStatus,
  }) async {
    _logger.i(
        'Updating quiz data: subjectId=$subjectId, quizTypeId=$quizTypeId, quizId=$quizId, isCorrect=$isCorrect, toggleReviewStatus=$toggleReviewStatus');

    // 현재 사용자가 없으면 경고 로그를 남기고 종료
    if (_user == null) {
      _logger.w('Attempted to update quiz data for null user');
      return;
    }

    try {
      var quizData = _quizData[subjectId]?[quizTypeId]?[quizId] ??
          QuizUserData(
            nextReviewDate: DateTime.now(),
            lastAnswered: DateTime.now(),
          );

      if (toggleReviewStatus != null) {
        final ankiResult = AnkiAlgorithm.calculateNextReview(
          interval: quizData.interval,
          easeFactor: quizData.easeFactor,
          consecutiveCorrect: quizData.consecutiveCorrect,
          isCorrect: isCorrect,
          qualityOfRecall: null,
          mistakeCount: quizData.mistakeCount,
          isUnderstandingImproved: isUnderstandingImproved,
          markForReview: toggleReviewStatus,
        );

        quizData.nextReviewDate = toggleReviewStatus
            ? DateTime.now().add(Duration(days: ankiResult['interval'] as int))
            : DateTime.now();
        quizData.markedForReview = toggleReviewStatus;
      } else {
        if (!quizData.markedForReview) {
          quizData.total++;
          if (isCorrect) {
            quizData.correct++;
            quizData.consecutiveCorrect++;
          } else {
            quizData.mistakeCount++;
            quizData.consecutiveCorrect = 0;
          }
        }

        int? qualityOfRecall;
        if (answerTime != null) {
          qualityOfRecall =
              AnkiAlgorithm.evaluateRecallQuality(answerTime, isCorrect);
        }

        final ankiResult = AnkiAlgorithm.calculateNextReview(
          interval: quizData.interval,
          easeFactor: quizData.easeFactor,
          consecutiveCorrect: quizData.consecutiveCorrect,
          isCorrect: isCorrect,
          qualityOfRecall: qualityOfRecall,
          mistakeCount: quizData.mistakeCount,
          isUnderstandingImproved: isUnderstandingImproved,
          markForReview: false,
        );

        // 학습데이터 업데이트하고 저장
        final now = DateTime.now();
        quizData.interval = ankiResult['interval'] as int;
        quizData.easeFactor = ankiResult['easeFactor'] as double;
        quizData.consecutiveCorrect = ankiResult['consecutiveCorrect'] as int;
        quizData.mistakeCount = ankiResult['mistakeCount'] as int;
        quizData.nextReviewDate = now.add(Duration(days: quizData.interval));
        quizData.lastAnswered = now;
        quizData.selectedOptionIndex = selectedOptionIndex;
        quizData.isUnderstandingImproved = isUnderstandingImproved;
        quizData.accuracy =
            quizData.total > 0 ? quizData.correct / quizData.total : 0.0;
      }

      _quizData[subjectId] ??= {};
      _quizData[subjectId]![quizTypeId] ??= {};
      _quizData[subjectId]![quizTypeId]![quizId] = quizData;

      await _saveQuizData();
      notifyListeners();

      _logger.i('사용자 퀴즈 데이터 업데이트 성공');
      _logger.d('업데이트 된 퀴즈 데이터: ${_quizData[subjectId]![quizTypeId]![quizId]}');
    } catch (e) {
      _logger.e('사용자 퀴즈 데이터 업데이트 실패: $e');
      rethrow;
    }
  }

  // 특정 퀴즈의 실수 횟수를 가져오는 메소드
  int getQuizMistakeCount(String subjectId, String quizTypeId, String quizId) {
    return _quizData[subjectId]?[quizTypeId]?[quizId]?.mistakeCount ?? 0;
  }

  // 사용자의 데이터를 Firebase에 동기화하는 메소드
  // --------- TODO : 가장 최신의 퀴즈 데이터를 덮어쓰고, 서버로 데이터 전송하는지 확인 ---------//
  Future<void> syncUserData() async {
    if (_user == null || !_needsSync) {
      _logger.w('유저${_user!.uid}의 데이터 동기화 필요 없음');
      return;
    }

    _logger.i('유저${_user!.uid}의 데이터를 Firebase에 동기화');
    try {
      // TODO : FirebaseStore이 아니라, firebasedatabase로 변경해야함.
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'quizData': _quizData,
      }, SetOptions(merge: true));
      _needsSync = false;
      _logger.i('��저${_user!.uid}의 데이터가 Firebase와 성공적으로 동기화되었습니다');

      // 로컬 저장소 업데이트
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'user_quiz_data_${_user!.uid}', json.encode(_quizData));
      _logger.i('유저${_user!.uid}의 퀴즈데이터가 로컬 저장소에 업데이트되었습니다');

      notifyListeners();
      _logger.i('유저${_user!.uid}의 데이터가 Firebase와 성공적으로 동기화되었습니다');
    } catch (e) {
      _logger.e('유저${_user!.uid}의 데이터 동기화 실패: $e');
    }
  }

  // 주의 사항:
  // 0으 나누는 상황을 방지해야 함.
  double getQuizAccuracy(String subjectId, String quizTypeId, String quizId) {
    final accuracy =
        _quizData[subjectId]?[quizTypeId]?[quizId]?.accuracy ?? 0.0;
    _logger.i(
        '유저${_user!.uid}의 퀴즈 정확도: subjectId=$subjectId, quizTypeId=$quizTypeId, quizId=$quizId, accuracy=$accuracy');
    return accuracy;
  }

  // 다음 복습 날짜를 가져오는 메서드
  // --------- TODO : 퀴즈 데이터를 불러오지 못하는 문제가 발생하고 있음. ---------//
  // --------- TODO : getNextReviewTimeString 메서드랑 합칠 수 있는지 봐야 함 ---------//
  DateTime? getNextReviewDate(
      String subjectId, String quizTypeId, String quizId) {
    // _quizData에서 퀴즈 데이터를 가져옴
    final quizData = _quizData[subjectId]?[quizTypeId]?[quizId];
    if (quizData == null) {
      _logger.w('퀴즈 데이터를 찾을 수 없음: $quizId. Returning null.');
      return null;
    }

    final nextReviewDate = quizData.nextReviewDate;
    return nextReviewDate.isAfter(DateTime.now())
        ? nextReviewDate
        : DateTime.now();
  }

  // 다음 복습 시간을 표시하는 메서드
  // --------- TODO : updateUserQuizData에 완전히 업데이트 된 정보가 출력되는지 확인 ---------//
  String getNextReviewTimeString(
      String subjectId, String quizTypeId, String quizId) {
    // _quizData에서 퀴즈데이터를 가지고 옴
    final quizData = _quizData[subjectId]?[quizTypeId]?[quizId];
    if (quizData == null) {
      _logger.w('No quiz data found for $quizId. Returning "지금"');
      return '지금';
    }

    // getNextReviewDate 메서드를 사용하여 다음 복습 날짜를 가져옴
    final nextReviewDate = getNextReviewDate(subjectId, quizTypeId, quizId);
    final now = DateTime.now();
    final difference = nextReviewDate?.difference(now) ?? Duration.zero;

    _logger.i('다음 복습을 계산 중인 퀴즈 : $quizId');
    _logger.d('다음 복습 날짜: $nextReviewDate');
    _logger.d('현재 날짜: $now');
    _logger.d('차이: $difference');

    if (kDebugMode) {
      if (difference.inMinutes > 0) {
        return '${difference.inMinutes} 분';
      } else {
        return '${difference.inSeconds} 초';
      }
    } else {
      if (difference.inDays > 0) {
        return '${difference.inDays} 일';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} 시간';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} 분';
      } else {
        return '${difference.inSeconds} 초';
      }
    }
  }

  // Update isQuizEligibleForReview method
  bool isQuizEligibleForReview(
      String subjectId, String quizTypeId, String quizId) {
    final quizData = _quizData[subjectId]?[quizTypeId]?[quizId];
    if (quizData == null) return false;

    final nextReviewDate = getNextReviewDate(subjectId, quizTypeId, quizId);
    return nextReviewDate != null && nextReviewDate.isBefore(DateTime.now());
  }

  // Add this method for offline support
  Future<void> syncOfflineData() async {
    _logger.i('오프라인 데이터 동기화 중');
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
                  subjectId, quizTypeId, quizId, quizData['isCorrect'],
                  selectedOptionIndex: quizData['selectedOptionIndex'],
                  answerTime: Duration(seconds: quizData['answerTime'] ?? 0),
                  isUnderstandingImproved:
                      quizData['isUnderstandingImproved'] ?? false,
                  toggleReviewStatus: quizData['toggleReviewStatus'] ?? false);
            }
          }
        }
        await prefs.remove('offline_quiz_data');
        _logger.i('오프라인 데이터 동기화 성공');
      }
    } catch (e) {
      _logger.e('오프라인 데이터 동기화 실패: $e');
    }
  }

  void logQuizData() {
    _logger.d('지금의 _quizData: $_quizData');
  }
}
