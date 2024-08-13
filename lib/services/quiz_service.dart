import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subject.dart';
import '../models/quiz_type.dart';
import '../models/quiz.dart';
import '../models/quiz_user_data.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/anki_algorithm.dart';

class QuizService {
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  static const String _subjectsKey = 'subjects'; // 과목 데이터 캐시 키
  static const String _quizTypesKey = 'quizTypes'; // 퀴즈 유형 데이터 캐시 키
  static const String _quizzesKey = 'quizzes'; // 퀴즈 데이터 캐시 키
  static const Duration _cacheExpiration = Duration(hours: 1); // 캐시 만료 시간

  final Map<String, List<Subject>> _cachedSubjects = {};
  final Map<String, Map<String, List<QuizType>>> _cachedQuizTypes = {};
  final Map<String, Map<String, Map<String, List<Quiz>>>> _cachedQuizzes = {};
  final Map<String, Map<String, Map<String, Map<String, QuizUserData>>>>
      _userQuizData = {};

  QuizService._internal();

  Future<void> loadUserQuizData(String userId) async {
    _logger.i('Loading quiz data for user: $userId');
    final prefs = await SharedPreferences.getInstance(); // 앱의 로컬 데이터 저장소에 접근
    final cachedData =
        prefs.getString('user_quiz_data_$userId'); // 사용자 퀴즈 데이터 캐시 데이터 가져오기

    // 캐시된 데이터가 존재하는지 확인
    if (cachedData != null) {
      // 캐시된 데이터를 사용자 퀴즈 데이터 맵에 로드
      _userQuizData[userId] =
          _convertToQuizUserDataMap(json.decode(cachedData));
      _logger.d('사용자 퀴즈 데이터 캐시 로드 완료: $userId');
    } else {
      // 캐시된 데이터가 없으면 Firestore에서 데이터 가져오기
      final docSnapshot =
          await _firestore.collection('users').doc(userId).get();
      final firestoreData =
          docSnapshot.data()?['quizData'] as Map<String, dynamic>? ?? {};

      // Firestore 데이터를 사용자 퀴즈 데이터 맵에 로드
      _userQuizData[userId] = _convertToQuizUserDataMap(firestoreData);
      _logger.d('Firestore 퀴즈 데이터 로드 완료: $userId');
    }
  }

  // userQuizData 저장하는 메소드
  Future<void> saveUserQuizData(String userId) async {
    _logger.i('사용자 퀴즈 데이터 저장 중: $userId');
    final prefs = await SharedPreferences.getInstance();
    final jsonData =
        json.encode(_convertFromQuizUserDataMap(_userQuizData[userId] ?? {}));
    await prefs.setString('user_quiz_data_$userId', jsonData);
    await _firestore.collection('users').doc(userId).set(
        {'quizData': _convertFromQuizUserDataMap(_userQuizData[userId] ?? {})},
        SetOptions(merge: true));
    _logger.d('사용자 퀴즈 데이터 저장 완료: $userId');

    // 새로운 로깅 추가
    _logger.d('사용자 퀴즈 데이터 저장 완료: $userId');
    _logger.d(json.encode(_userQuizData[userId]));
  }

  // --------- TODO : 정확도, 다음 복습 날짜 변수 추가해야함 ---------//
  Future<void> updateUserQuizData(
    String userId,
    String subjectId,
    String quizTypeId,
    String quizId,
    bool isCorrect, {
    Duration? answerTime,
    int? selectedOptionIndex,
    bool isUnderstandingImproved = false,
    bool? toggleReviewStatus,
  }) async {
    _logger.i(
        '사용자 퀴즈 데이터 업데이트 중: user=$userId, subject=$subjectId, quizType=$quizTypeId, quiz=$quizId, correct=$isCorrect');
    _userQuizData[userId] ??= {};
    _userQuizData[userId]![subjectId] ??= {};
    _userQuizData[userId]![subjectId]![quizTypeId] ??= {};
    _userQuizData[userId]![subjectId]![quizTypeId]![quizId] ??= QuizUserData(
      nextReviewDate: DateTime.now(),
      lastAnswered: DateTime.now(),
    );

    var quizData = _userQuizData[userId]![subjectId]![quizTypeId]![quizId]!;

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

      quizData.interval = ankiResult['interval'] as int;
      quizData.easeFactor = ankiResult['easeFactor'] as double;
      quizData.consecutiveCorrect = ankiResult['consecutiveCorrect'] as int;
      quizData.mistakeCount = ankiResult['mistakeCount'] as int;
      quizData.nextReviewDate =
          DateTime.now().add(Duration(days: quizData.interval));
      quizData.lastAnswered = DateTime.now();
      quizData.selectedOptionIndex = selectedOptionIndex;
      quizData.isUnderstandingImproved = isUnderstandingImproved;
      quizData.accuracy =
          quizData.total > 0 ? quizData.correct / quizData.total : 0.0;
    }

    _logger.d('사용자 퀴즈 데이터 업데이트 완료: $userId');
    _logger.d('업데이트된 정확도: ${quizData.accuracy}');
    _logger.d('다음 복습 날짜: ${quizData.nextReviewDate}');

    await saveUserQuizData(userId);
  }

  // --------- TODO : 복습 퀴즈 가져오는 메소드 ---------//
  Future<List<Quiz>> getQuizzesForReview(
      String userId, String subjectId, String quizTypeId) async {
    _logger.i(
        '복습 퀴즈 가져오기: user=$userId, subject=$subjectId, quizType=$quizTypeId');

    // Validate subjectId and quizTypeId
    if (subjectId.isEmpty || quizTypeId.isEmpty) {
      _logger.e('subjectId 또는 quizTypeId가 비어있습니다');
      return []; // 아이디가 비어있으면 빈 리스트 반환
    }

    await loadUserQuizData(userId); // TODO: 가장 최신의 사용자 퀴즈 데이터 로드가 되는지 확인해야함

    // 전체 퀴즈를 가지고 옴
    final quizzes = await getQuizzes(subjectId, quizTypeId);
    // 현재 시간 가져옴
    final now = DateTime.now();

    // 다음 복습 날짜를 기준으로 복습할 퀴즈 필터링
    List<Quiz> quizzesForReview = quizzes.where((quiz) {
      final quizData = _userQuizData[userId]?[subjectId]?[quizTypeId]?[quiz.id];
      return quizData != null && quizData.nextReviewDate.isBefore(now);
    }).toList();

    // 실수 횟수를 기준으로 퀴즈 정렬 (내림차순)
    quizzesForReview.sort((a, b) {
      final aData = _userQuizData[userId]![subjectId]![quizTypeId]![a.id]!;
      final bData = _userQuizData[userId]![subjectId]![quizTypeId]![b.id]!;
      return bData.mistakeCount.compareTo(aData.mistakeCount);
    });

    _logger.d('Found ${quizzesForReview.length} quizzes for review');
    return quizzesForReview;
  }

  // userQuizData 가져오는 메소드
  Map<String, dynamic> getUserQuizData(String userId) {
    _logger.i('사용자 퀴즈 데이터 가져오기: $userId');
    return _convertFromQuizUserDataMap(_userQuizData[userId] ?? {});
  }

  Future<List<Subject>> getSubjects() async {
    _logger.i('과목을 가져오는 중입니다');
    const key = _subjectsKey;
    if (_cachedSubjects.containsKey(key)) {
      _logger.d('메모리 캐시에서 과목을 가져왔습니다');
      return _cachedSubjects[key]!;
    }

    try {
      final subjects = await _getDataWithCache<List<Subject>>(
        key: key,
        fetchFromFirestore: () async {
          _logger.d('Firestore에서 과목을 가져오는 중입니다');
          final snapshot = await _firestore.collection('subjects').get();
          return snapshot.docs
              .map((doc) => Subject.fromFirestore(doc))
              .toList();
        },
        parseData: (data) => (json.decode(data) as List)
            .map((item) => Subject.fromJson(item as Map<String, dynamic>))
            .toList(),
        encodeData: (subjects) =>
            json.encode(subjects.map((s) => s.toJson()).toList()),
      );

      _cachedSubjects[key] = subjects;
      _logger.i('과목을 가져왔습니다: ${subjects.length}');
      return subjects;
    } catch (e) {
      _logger.e('과목을 가져오는 중 오류가 발생했습니다: $e');
      rethrow;
    }
  }

  // 수정: Stream 대신 Future를 반환하록 변경
  Future<List<QuizType>> getQuizTypes(String subjectId) async {
    _logger.i('과목 $subjectId에 대한 퀴즈 타입을 가져오는 중입니다');
    final key = '${_quizTypesKey}_$subjectId';
    if (_cachedQuizTypes.containsKey(subjectId) &&
        _cachedQuizTypes[subjectId]!.containsKey(key)) {
      _logger.d('메모리 캐시에서 퀴즈 타입을 가져왔습니다: $subjectId');
      return _cachedQuizTypes[subjectId]![key]!;
    }

    try {
      final quizTypes = await _getDataWithCache<List<QuizType>>(
        key: key,
        fetchFromFirestore: () async {
          final snapshot = await _firestore
              .collection('subjects')
              .doc(subjectId)
              .collection('quizTypes')
              .get();
          return snapshot.docs
              .map((doc) => QuizType.fromFirestore(doc))
              .toList();
        },
        parseData: (data) => (json.decode(data) as List)
            .map((item) => QuizType.fromJson(item as Map<String, dynamic>))
            .toList(),
        encodeData: (quizTypes) =>
            json.encode(quizTypes.map((qt) => qt.toJson()).toList()),
      );

      _cachedQuizTypes[subjectId] = {key: quizTypes};
      _logger.i('과목 $subjectId에 대한 퀴즈 타입을 가져왔습니다: ${quizTypes.length}');
      return quizTypes;
    } catch (e) {
      _logger.e('과목 $subjectId에 대한 퀴즈 타입을 가져오는 중 오류가 발생했습니다: $e');
      rethrow;
    }
  }

  // 수정: Stream 대신 Future를 반환하도록 변경
  // --------- TODO : 모든 과목을 한번에 가져올지 고민해봐야함. ---------//
  // --------- TODO : 퀴즈 데이터를 가져오는 로직을 로컬데이터를 가져오는 로직을 추가해야함 ---------//
  // Quizpage에서 퀴즈 데이터를 가져오는 함수
  Future<List<Quiz>> getQuizzes(String subjectId, String quizTypeId) async {
    // 퀴즈를 가져오는 중임을 로그로 기록
    _logger.i('과목 $subjectId에 대한 퀴즈를 가져오는 중입니다: $quizTypeId');

    // 캐시 키 생성
    final key = '${_quizzesKey}_${subjectId}_$quizTypeId';

    // 캐시에서 퀴즈가 존재하는지 확인
    if (_cachedQuizzes.containsKey(subjectId) &&
        _cachedQuizzes[subjectId]!.containsKey(quizTypeId) &&
        _cachedQuizzes[subjectId]![quizTypeId]!.containsKey(key)) {
      // 캐시에서 퀴즈를 가져왔음을 로그로 기록
      _logger.d('메모리 캐시에서 퀴즈를 가져왔습니다: $subjectId, $quizTypeId');
      return _cachedQuizzes[subjectId]![quizTypeId]![key]!;
    }

    try {
      // 캐시 또는 Firestore에서 퀴즈 데이터를 가져옴
      final quizzes = await _getDataWithCache<List<Quiz>>(
        key: key,
        fetchFromFirestore: () async {
          // Firestore에서 퀴��� 데이터를 가져옴
          final snapshot = await _firestore
              .collection('subjects')
              .doc(subjectId)
              .collection('quizTypes')
              .doc(quizTypeId)
              .collection('quizzes')
              .get();
          // Firestore 문서를 Quiz 객체로 변환하여 리스트로 반환
          return snapshot.docs
              .map((doc) => Quiz.fromFirestore(doc, _logger))
              .toList();
        },
        // 캐시된 데이터 파싱 방법 정의
        parseData: (data) => (json.decode(data) as List)
            .map((item) => Quiz.fromJson(item as Map<String, dynamic>))
            .toList(),
        // 퀴즈 데이터를 JSON으로 인코딩
        encodeData: (quizzes) =>
            json.encode(quizzes.map((q) => q.toJson()).toList()),
      );

      // 캐시에 퀴즈 데이터 저장
      _cachedQuizzes[subjectId] = {
        quizTypeId: {key: quizzes}
      };
      _logger.i(
          '과목 $subjectId 및 퀴즈 유형 $quizTypeId에 대한 퀴즈를 가져왔습니다: ${quizzes.length}');
      return quizzes;
    } catch (e) {
      _logger
          .e('과목 $subjectId 및 퀴즈 유형 $quizTypeId에 대한 퀴즈를 가져오는 중 오류가 발생했습니다: $e');
      rethrow;
    }
  }

  Future<T> _getDataWithCache<T>({
    required String key,
    required Future<T> Function() fetchFromFirestore,
    required T Function(String) parseData,
    required String Function(T) encodeData,
  }) async {
    _logger.d('캐시를 사용하여 데이터 가져오는 중: $key');
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(key);
    final cacheTimestamp = prefs.getInt('${key}_timestamp');

    if (cachedData != null && cacheTimestamp != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - cacheTimestamp < _cacheExpiration.inMilliseconds) {
        _logger.d('캐시된 데이터 사용: $key');
        return parseData(cachedData);
      }
    }

    final data = await fetchFromFirestore();
    final jsonData = encodeData(data);
    await prefs.setString(key, jsonData);
    await prefs.setInt(
        '${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
    _logger.d('Firestore에서 데이터를 가져왔고 캐시되었습니다: $key');
    return data;
  }

  Future<void> addQuizTypeToSubject(String subjectId, String typeName) async {
    try {
      final quizTypeId = _uuid.v4();
      final quizTypeData =
          QuizType(id: quizTypeId, name: typeName, subjectId: subjectId);

      await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('quizTypes')
          .doc(quizTypeId)
          .set(quizTypeData.toFirestore());

      // 수정: 캐시 업데이트 로직 개선
      final key = '${_quizTypesKey}_$subjectId';
      _cachedQuizTypes[subjectId] ??= {};
      _cachedQuizTypes[subjectId]![key] ??= [];
      _cachedQuizTypes[subjectId]![key]!.add(quizTypeData);

      _logger.i('과목 $subjectId에 퀴즈 유형을 추가했습니다');
    } catch (e) {
      _logger.e('과목 $subjectId에 퀴즈 유형을 추가하는 중 오류가 발생했습니다: $e');
      rethrow;
    }
  }

  Future<void> addSubject(String name) async {
    try {
      final newSubject = Subject(id: _uuid.v4(), name: name);
      await _firestore.collection('subjects').add(newSubject.toFirestore());

      // 수정: 캐시 업데이트 로직 개선
      _cachedSubjects[_subjectsKey] ??= [];
      _cachedSubjects[_subjectsKey]!.add(newSubject);

      _logger.i('과목을 추가했습니다: ${newSubject.name}');
    } catch (e) {
      _logger.e('과목을 추가하는 중 오류가 발생했습니다: $e');
      rethrow;
    }
  }

  Future<void> addQuiz(String subjectId, String quizTypeId, Quiz quiz) async {
    _logger.i('과목 $subjectId에 퀴즈를 추가하는 중입니다: $quizTypeId');
    try {
      final quizData = quiz.toFirestore();

      // Store only the Firebase Storage path, not the full URL
      if (quiz.imageUrl != null) {
        if (quiz.imageUrl!.startsWith('http')) {
          final uri = Uri.parse(quiz.imageUrl!);
          quizData['imageUrl'] =
              uri.path.replaceFirst('/o/', '').split('?').first;
        } else if (!quiz.imageUrl!.startsWith('quiz_images/')) {
          quizData['imageUrl'] = 'quiz_images/${quiz.imageUrl}';
        }
      }
      final docRef = await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('quizTypes')
          .doc(quizTypeId)
          .collection('quizzes')
          .add(quizData);

      _logger.i('과목 $subjectId에 퀴즈를 추가했습니다: ${docRef.id}');

      final updatedQuiz = Quiz(
        id: docRef.id,
        question: quiz.question,
        options: quiz.options,
        correctOptionIndex: quiz.correctOptionIndex,
        explanation: quiz.explanation,
        typeId: quiz.typeId,
        keywords: quiz.keywords,
        imageUrl: quizData['imageUrl'],
        year: quiz.year,
      );

      // 캐시 업데이트 로직 개선
      final key = '${_quizzesKey}_${subjectId}_$quizTypeId';
      _cachedQuizzes[subjectId] ??= {};
      _cachedQuizzes[subjectId]![quizTypeId] ??= {};
      _cachedQuizzes[subjectId]![quizTypeId]![key] ??= [];
      _cachedQuizzes[subjectId]![quizTypeId]![key]!.add(updatedQuiz);

      // 캐시 데이터를 SharedPreferences에 저장
      await _updateSharedPreferences(subjectId, quizTypeId);
    } catch (e) {
      _logger.e('과목 $subjectId에 퀴즈를 추가하는 중 오류가 발생했습니다: $e');
      rethrow;
    }
  }

  Future<void> updateQuiz(
      String subjectId, String quizTypeId, Quiz quiz) async {
    try {
      await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('quizTypes')
          .doc(quizTypeId)
          .collection('quizzes')
          .doc(quiz.id)
          .update(quiz.toFirestore());

      // 수정: 캐시 업데이트 로직 개선
      final key = '${_quizzesKey}_${subjectId}_$quizTypeId';
      if (_cachedQuizzes[subjectId]?[quizTypeId]?[key] != null) {
        final index = _cachedQuizzes[subjectId]![quizTypeId]![key]!
            .indexWhere((q) => q.id == quiz.id);
        if (index != -1) {
          _cachedQuizzes[subjectId]![quizTypeId]![key]![index] = quiz;
        }
      }

      _logger.i('과목 $subjectId에 퀴즈를 업데이트했습니다: ${quiz.id}');

      // 캐시 데이터를 SharedPreferences에 저장
      await _updateSharedPreferences(subjectId, quizTypeId);
    } catch (e) {
      _logger.e('과목 $subjectId에 퀴즈를 업데이트하는 중 오류가 발생했습니다: $e');
      rethrow;
    }
  }

  Future<void> deleteQuiz(
      String subjectId, String quizTypeId, String quizId) async {
    try {
      await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('quizTypes')
          .doc(quizTypeId)
          .collection('quizzes')
          .doc(quizId)
          .delete();

      // 수정: 캐시 업데이트 로직 개선
      final key = '${_quizzesKey}_${subjectId}_$quizTypeId';
      _cachedQuizzes[subjectId]?[quizTypeId]?[key]
          ?.removeWhere((q) => q.id == quizId);

      _logger.i('과목 $subjectId에 퀴즈를 삭제했습니다: $quizId');

      // 캐시 데이터를 SharedPreferences에 저장
      await _updateSharedPreferences(subjectId, quizTypeId);
    } catch (e) {
      _logger.e('과목 $subjectId에 퀴즈를 삭제하는 중 오류가 발생했습니다: $e');
      rethrow;
    }
  }

  // 새로 추가: SharedPreferences 업데이트 메서드
  Future<void> _updateSharedPreferences(
      String subjectId, String quizTypeId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_quizzesKey}_${subjectId}_$quizTypeId';
    if (_cachedQuizzes[subjectId]?[quizTypeId]?[key] != null) {
      final quizzesJson = json.encode(
          _cachedQuizzes[subjectId]![quizTypeId]![key]!
              .map((q) => q.toFirestore())
              .toList());
      await prefs.setString(key, quizzesJson);
      await prefs.setInt(
          '${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
    }
  }

  // 새로 추가: 메모리 캐시 새로고침 메서드
  Future<void> refreshCache() async {
    _logger.i('메모리 캐시를 새로고침하는 중입니다');
    _cachedSubjects.clear();
    _cachedQuizTypes.clear();
    _cachedQuizzes.clear();

    await getSubjects();
    final subjects = await getSubjects();
    for (final subject in subjects) {
      final quizTypes = await getQuizTypes(subject.id);
      for (final quizType in quizTypes) {
        await getQuizzes(subject.id, quizType.id);
      }
    }
    _logger.i('메모리 캐시를 새로고침했습니다');
  }

  // 새로 추가: 특정 주제의 즈 타입 및 퀴즈 새로고침 메서드
  Future<void> refreshSubjectData(String subjectId) async {
    _logger.i('과목 $subjectId에 대한 데이터를 새로고침하는 중입니다');
    _cachedQuizTypes.remove(subjectId);
    _cachedQuizzes.remove(subjectId);

    final quizTypes = await getQuizTypes(subjectId);
    for (final quizType in quizTypes) {
      await getQuizzes(subjectId, quizType.id);
    }
    _logger.i('과목 $subjectId에 대한 데이터를 새로고침했습니다');
  }

  // New method to generate performance analytics
  Future<Map<String, dynamic>> generatePerformanceAnalytics(
      String userId, String subjectId) async {
    _logger.i('사용자 $userId에 대한 성능 분석을 생성하는 중입니다: 과목 $subjectId');
    try {
      await loadUserQuizData(userId);
      final userData = _userQuizData[userId];
      final subjectData = userData?[subjectId];

      if (subjectData == null) {
        return {'error': '이 과목에 대한 데이터가 없습니다'}; // 주제 데이터가 없을 경우 오류 반환
      }

      int totalQuizzes = 0;
      int totalCorrect = 0;
      int totalMistakes = 0;
      List<Map<String, dynamic>> quizTypePerformance = [];
      List<Map<String, dynamic>> recentPerformance = [];

      subjectData.forEach((quizTypeId, quizzes) {
        int quizTypeTotal = 0;
        int quizTypeCorrect = 0;
        int quizTypeMistakes = 0;

        quizzes.forEach((quizId, quizData) {
          quizTypeTotal += quizData.total;
          quizTypeCorrect += quizData.correct;
          quizTypeMistakes += quizData.mistakeCount;

          recentPerformance.add({
            'quizId': quizId,
            'lastAnswered': quizData.lastAnswered.toIso8601String(),
            'isCorrect': quizData.correct == quizData.total,
          });
        });

        totalQuizzes += quizTypeTotal;
        totalCorrect += quizTypeCorrect;
        totalMistakes += quizTypeMistakes;

        quizTypePerformance.add({
          'quizTypeId': quizTypeId,
          'total': quizTypeTotal,
          'correct': quizTypeCorrect,
          'accuracy': quizTypeTotal > 0 ? quizTypeCorrect / quizTypeTotal : 0,
          'mistakes': quizTypeMistakes,
        });
      });

      // Sort recent performance by date and limit to last 10 entries
      recentPerformance.sort((a, b) => DateTime.parse(b['lastAnswered'])
          .compareTo(DateTime.parse(a['lastAnswered'])));
      recentPerformance = recentPerformance.take(10).toList();

      return {
        'totalQuizzes': totalQuizzes,
        'totalCorrect': totalCorrect,
        'overallAccuracy': totalQuizzes > 0 ? totalCorrect / totalQuizzes : 0,
        'totalMistakes': totalMistakes,
        'quizTypePerformance': quizTypePerformance,
        'recentPerformance': recentPerformance,
      };
    } catch (e) {
      _logger.e('사용자 $userId에 대한 성능 분석을 생성하는 중 오류가 발생했습니다: $e');
      return {'error': '성능 분석을 생성하는 중 오류가 발생했습니다'};
    }
  }

  Future<List<Quiz>> getQuizzesByIds(
      String subjectId, String quizTypeId, List<String> quizIds) async {
    _logger.i('과목 $subjectId에 대한 퀴즈를 가져오는 중입니다: $quizTypeId');
    try {
      final quizzes = await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('quizTypes')
          .doc(quizTypeId)
          .collection('quizzes')
          .where(FieldPath.documentId, whereIn: quizIds)
          .get();

      return quizzes.docs
          .map((doc) => Quiz.fromFirestore(doc, _logger))
          .toList();
    } catch (e) {
      _logger.e('과목 $subjectId에 대한 퀴즈를 가져오는 중 오류가 발생했습니다: $e');
      rethrow;
    }
  }

  Future<void> syncUserData(
      String userId, Map<String, dynamic> userData) async {
    _logger.i('사용자 $userId에 대한 데이터를 동기화하는 중입니다');
    try {
      _userQuizData[userId] = _convertToQuizUserDataMap(userData);
      await saveUserQuizData(userId);
      _logger.i('사용자 $userId에 대한 데이터를 동기화했습니다');
      _logger.d('동기화된 사용자 데이터: $userData');
    } catch (e) {
      _logger.e('사용자 $userId에 대한 데이터를 동기화하는 중 오류가 발생했습니다: $e');
      rethrow;
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

  Map<String, dynamic> _convertFromQuizUserDataMap(
      Map<String, Map<String, Map<String, QuizUserData>>> data) {
    return data.map((subjectId, subjectData) {
      return MapEntry(
        subjectId,
        subjectData.map((quizTypeId, quizTypeData) {
          return MapEntry(
            quizTypeId,
            quizTypeData.map((quizId, quizData) {
              return MapEntry(quizId, quizData.toJson());
            }),
          );
        }),
      );
    });
  }

  Future<void> resetUserQuizData(
      String userId, String subjectId, String quizTypeId, String quizId) async {
    _logger.i(
        '사용자 $userId의 퀴즈 데이터 리셋 중: subject=$subjectId, quizType=$quizTypeId, quiz=$quizId');
    try {
      _userQuizData[userId]?[subjectId]?[quizTypeId]?[quizId] = QuizUserData(
        nextReviewDate: DateTime.now(),
        lastAnswered: DateTime.now(),
      );

      await saveUserQuizData(userId);
      _logger.d('사용자 퀴즈 데이터 리셋 완료');
    } catch (e) {
      _logger.e('사용자 퀴즈 데이터 리셋 중 오류 발생: $e');
      rethrow;
    }
  }

  double getQuizAccuracy(
      String userId, String subjectId, String quizTypeId, String quizId) {
    final quizData = _userQuizData[userId]?[subjectId]?[quizTypeId]?[quizId];
    if (quizData == null || quizData.total == 0) {
      return 0.0;
    }
    return quizData.correct / quizData.total;
  }
}
