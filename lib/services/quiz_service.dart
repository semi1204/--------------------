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
import 'dart:async';

// TODO : 무조건 firebase에서 데이터 파싱하지 말고, 로컬스토리지에서 가져오도록 수정해야함
// TODO : 로컬스토리지에서 가져오는 방법 찾아보기
// TODO : firebase와 연동은 동기화버튼으로 user_quiz_data_${userId} 데이터를 보내고, 받아야 함.
// TODO : 모든 문제를 한번에 파싱하지 말고, 부분적으로 파싱하는 걸 생각해야 함.
// 데이터를 보내고 받을 때의 원칙은 무조건, 최신의 데이터를 덮어쓰는 방식으로 최대한 적은 데이터를 송수신하게 해야함
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
  // 로컬 스토리지에서 사용자 퀴즈 데이터를 로드하는 메소드

  Future<void> loadUserQuizData(String userId) async {
    _logger.i('사용자 $userId의 퀴즈 데이터를 로드하는 중');
    try {
      final prefs = await SharedPreferences.getInstance(); // 앱의 로컬 데이터 저장소에 접근
      final String? jsonString = prefs
          .getString('user_quiz_data_$userId'); // 로컬 저장소에서 퀴즈 데이터를 문자열로 가져옴
      if (jsonString != null) {
        // 로컬 저장소에 퀴즈 데이터가 있으면
        final Map<String, dynamic> jsonData =
            json.decode(jsonString); // 문자열을 Map으로 변환
        _userQuizData[userId] = _convertToQuizUserDataMap(
            jsonData); // Map을 QuizUserData 객체로 변환하여 저장
        _logger.i('로컬 스토리지에서 사용자 $userId의 퀴즈 데이터를 로드했습니다');
      } else {
        // 로컬 저장소에 퀴즈 데이터가 없으면
        _logger.i('로컬 스토리지에 사용자 $userId의 데이터가 없습니다. Firebase에서 로드를 시도합니다.');
        await _loadUserQuizDataFromFirebase(userId); // Firebase에서 퀴즈 데이터를 로드
      }
    } catch (e) {
      _logger.e('사용자 $userId의 퀴즈 데이터를 로드하는 중 오류 발생: $e');
      rethrow;
    }
  }

  // Firebase에서 사용자 퀴즈 데이터를 로드하는 메소드
  Future<void> _loadUserQuizDataFromFirebase(String userId) async {
    try {
      final docSnapshot =
          await _firestore.collection('users').doc(userId).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        _userQuizData[userId] = _convertToQuizUserDataMap(data);
        _logger.i('Firebase에서 사용자 $userId의 퀴즈 데이터를 로드했습니다');
      } else {
        _logger.w('Firebase에 사용자 $userId의 데이터가 없습니다');
      }
    } catch (e) {
      _logger.e('Firebase에서 사용자 $userId의 퀴즈 데이터를 로드하는 중 오류 발생: $e');
      rethrow;
    }
  }

  // 로컬 스토리지에 사용자 퀴즈 데이터를 저장하는 메소드
  Future<void> saveUserQuizData(String userId) async {
    _logger.i('사용자 $userId의 퀴즈 데이터를 저장하는 중');
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = json.encode(_userQuizData[userId]);
      await prefs.setString('user_quiz_data_$userId', jsonString);
      _logger.i('사용자 $userId의 퀴즈 데이터를 로컬 스토리지에 저장했습니다');
    } catch (e) {
      _logger.e('사용자 $userId의 퀴즈 데이터를 저장하는 중 오류 발생: $e');
      rethrow;
    }
  }

  // Firebase와 데이터를 동기화하는 메소드
  Future<void> syncUserData(
      String userId, Map<String, dynamic> userData) async {
    _logger.i('사용자 $userId의 데이터를 동기화하는 중');
    try {
      // 로컬 데이터를 Firebase로 전송
      await _sendDataToFirebase(userId, userData);

      // Firebase에서 최신 데이터를 받아옴
      final firebaseData = await _getDataFromFirebase(userId);

      // 로컬 데이터 업데이트
      _userQuizData[userId] = _convertToQuizUserDataMap(firebaseData);
      await saveUserQuizData(userId);

      _logger.i('사용자 $userId의 데이터 동기화 완료');
    } catch (e) {
      _logger.e('사용자 $userId의 데이터 동기화 중 오류 발생: $e');
      rethrow;
    }
  }

  // Firebase로 데이터를 전송하는 메소드
  Future<void> _sendDataToFirebase(
      String userId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .set(data, SetOptions(merge: true));
      _logger.i('사용자 $userId의 데이터를 Firebase로 전송했습니다');
    } catch (e) {
      _logger.e('사용자 $userId의 데이터를 Firebase로 전송하는 중 오류 발생: $e');
      rethrow;
    }
  }

  // Firebase에서 데이터를 받아오는 메소드
  Future<Map<String, dynamic>> _getDataFromFirebase(String userId) async {
    try {
      final docSnapshot =
          await _firestore.collection('users').doc(userId).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        _logger.i('Firebase에서 사용자 $userId의 데이터를 받아왔습니다');
        return data;
      } else {
        _logger.w('Firebase에 사용자 $userId의 데이터가 없습니다');
        return {};
      }
    } catch (e) {
      _logger.e('Firebase에서 사용자 $userId의 데이터를 받아오는 중 오류 발생: $e');
      rethrow;
    }
  }

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

    if (!_userQuizData.containsKey(userId)) {
      _userQuizData[userId] = {};
    }
    if (!_userQuizData[userId]!.containsKey(subjectId)) {
      _userQuizData[userId]![subjectId] = {};
    }
    if (!_userQuizData[userId]![subjectId]!.containsKey(quizTypeId)) {
      _userQuizData[userId]![subjectId]![quizTypeId] = {};
    }
    if (!_userQuizData[userId]![subjectId]![quizTypeId]!.containsKey(quizId)) {
      _userQuizData[userId]![subjectId]![quizTypeId]![quizId] = QuizUserData(
        lastAnswered: DateTime.now(),
      );
    }

    var quizData = _userQuizData[userId]![subjectId]![quizTypeId]![quizId]!;

    // toggleReviewStatus가 true이거 이미 복습 리스트에 있는 경우에만 Anki 알고리즘 적용
    if (toggleReviewStatus == true || quizData.markedForReview) {
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
        markForReview: true,
      );

      quizData.interval = ankiResult['interval'] as int;
      quizData.easeFactor = ankiResult['easeFactor'] as double;
      quizData.consecutiveCorrect = ankiResult['consecutiveCorrect'] as int;
      quizData.mistakeCount = ankiResult['mistakeCount'] as int;
      quizData.nextReviewDate = AnkiAlgorithm.calculateNextReviewDate(
        quizData.interval,
        quizData.easeFactor,
      );
      _logger
          .d('다음 복습 날짜: ${quizData.nextReviewDate}, 간격: ${quizData.interval}');
    }

    if (isCorrect) {
      quizData.correct++;
    }
    quizData.total++;
    quizData.lastAnswered = DateTime.now();
    if (selectedOptionIndex != null) {
      quizData.selectedOptionIndex = selectedOptionIndex;
    }
    quizData.isUnderstandingImproved = isUnderstandingImproved;
    quizData.accuracy =
        quizData.total > 0 ? quizData.correct / quizData.total : 0.0;

    if (toggleReviewStatus != null) {
      quizData.markedForReview = toggleReviewStatus;
      if (toggleReviewStatus) {
        // 복습 리스트에 추가될 때 nextReviewDate 설정
        quizData.nextReviewDate = DateTime.now()
            .add(const Duration(minutes: AnkiAlgorithm.initialInterval));
      } else {
        // 복습 리스트에서 제거될 때 Anki 관련 데이터 초기화
        quizData.interval = AnkiAlgorithm.initialInterval;
        quizData.easeFactor = AnkiAlgorithm.defaultEaseFactor;
        quizData.consecutiveCorrect = 0;
        quizData.mistakeCount = 0;
        quizData.nextReviewDate = null;
      }
    }

    await saveUserQuizData(userId); // Ensure data is saved locally
    _logger.d('사용자 퀴즈 데이터 업데이트 완료');

    // Added: Trigger synchronization after updating quiz data
    await syncUserData(userId, getUserQuizData(userId));
  }

  // 복습리스트에 복습카드를 추가하는 메소드
  Future<void> addToReviewList(
      String userId, String subjectId, String quizTypeId, String quizId) async {
    _logger.i(
        'Adding quiz to review list: user=$userId, subject=$subjectId, quizType=$quizTypeId, quiz=$quizId');

    _userQuizData[userId] ??= {};
    _userQuizData[userId]![subjectId] ??= {};
    _userQuizData[userId]![subjectId]![quizTypeId] ??= {};
    _userQuizData[userId]![subjectId]![quizTypeId]![quizId] ??= QuizUserData(
      nextReviewDate: DateTime.now(),
      lastAnswered: DateTime.now(),
    );
    // 퀴즈ID가 복습리스트에 존재하게 됨
    var quizData = _userQuizData[userId]![subjectId]![quizTypeId]![quizId]!;
    // 퀴즈ID가 복습리스트에 존재하게
    quizData.markedForReview = true;
    quizData.nextReviewDate = DateTime.now()
        .add(const Duration(minutes: AnkiAlgorithm.initialInterval));

    _logger.d('복습 목록에 퀴즈를 추가함: quizId=$quizId');

    await saveUserQuizData(userId);
  }

  // 복습리스트에 복습카드를 제거하는 메소드
  Future<void> removeFromReviewList(
      String userId, String subjectId, String quizTypeId, String quizId) async {
    _logger.i(
        'Removing quiz from review list: user=$userId, subject=$subjectId, quizType=$quizTypeId, quiz=$quizId');

    var quizData = _userQuizData[userId]?[subjectId]?[quizTypeId]?[quizId];
    if (quizData != null) {
      quizData.markedForReview = false;
      quizData.interval = 0;
      quizData.easeFactor = AnkiAlgorithm.defaultEaseFactor;
      quizData.consecutiveCorrect = 0;
      quizData.mistakeCount = 0;
      _logger.d('복습 목록에서 퀴즈를 제거하고 데이터를 초기화함: quizId=$quizId');
    } else {
      _logger.w('사용자 데이터에서 퀴즈를 찾을 수 없음: quizId=$quizId');
    }

    await saveUserQuizData(userId);
  }

  bool isInReviewList(
      String userId, String subjectId, String quizTypeId, String quizId) {
    return _userQuizData[userId]?[subjectId]?[quizTypeId]?[quizId]
            ?.markedForReview ??
        false;
  }

  DateTime? getNextReviewDate(
      String userId, String subjectId, String quizTypeId, String quizId) {
    return _userQuizData[userId]?[subjectId]?[quizTypeId]?[quizId]
        //`_userQuizData`에서 주어진 ID들로 접근하여 해당 퀴즈의 `nextReviewDate`를 가져옴.
        ?.nextReviewDate;
  }

  Future<List<Quiz>> getQuizzesForReview(
      String userId, String subjectId, String? quizTypeId) async {
    _logger.i(
        'Getting quizzes for review: user=$userId, subject=$subjectId, quizType=$quizTypeId');

    List<Quiz> reviewQuizzes = [];
    final now = DateTime.now();

    final subjectData = _userQuizData[userId]?[subjectId];
    if (subjectData == null) {
      _logger
          .w('Subject data not found for user $userId and subject $subjectId');
      return reviewQuizzes;
    }

    for (var typeId in subjectData.keys) {
      if (quizTypeId != null && typeId != quizTypeId) continue;

      final typeData = subjectData[typeId];
      if (typeData == null) continue;

      for (var quizId in typeData.keys) {
        final quizData = typeData[quizId];
        if (quizData == null) continue;

        if (quizData.markedForReview &&
            quizData.nextReviewDate != null &&
            quizData.nextReviewDate!.isBefore(now)) {
          final quiz = await _getQuizById(subjectId, typeId, quizId);
          if (quiz != null) {
            reviewQuizzes.add(quiz);
          }
        }
      }
    }

    _logger.d('복습 퀴즈를 찾았습니다: ${reviewQuizzes.length}');
    return reviewQuizzes;
  }

  // 퀴즈 ID로 퀴즈를 가져오는 메소드
  Future<Quiz?> _getQuizById(
      String subjectId, String quizTypeId, String quizId) async {
    try {
      final docSnapshot = await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('quizTypes')
          .doc(quizTypeId)
          .collection('quizzes')
          .doc(quizId)
          .get();

      if (docSnapshot.exists) {
        return Quiz.fromFirestore(docSnapshot, _logger);
      } else {
        _logger.w('퀴즈를 찾을 수 없음: quizId=$quizId');
        return null;
      }
    } catch (e) {
      _logger.e('퀴즈를 가져오는 중 오류 발생: $e');
      return null;
    }
  }

  // userQuizData 가져오는 메소드
  Map<String, dynamic> getUserQuizData(String userId) {
    _logger.i('사용자 퀴즈 데이터 가져오기: $userId');
    final data = _convertFromQuizUserDataMap(_userQuizData[userId] ?? {});
    _logger.d('User quiz data: $data');
    return data;
  }

  Future<List<Subject>> getSubjects({bool forceRefresh = false}) async {
    _logger.i('과목을 가져오는 중입니다');
    const key = _subjectsKey;
    if (!forceRefresh && _cachedSubjects.containsKey(key)) {
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
        forceRefresh: forceRefresh,
      );

      _cachedSubjects[key] = subjects;
      _logger.i('과목을 가져왔습니다: ${subjects.length}');
      return subjects;
    } catch (e) {
      _logger.e('과목을 가져오는 중 오류가 발생했습니다: $e');
      rethrow;
    }
  }

  Future<List<QuizType>> getQuizTypes(String subjectId,
      {bool forceRefresh = false}) async {
    _logger.i('과목 $subjectId에 대한 퀴즈 타입을 가져오는 중입니다');
    final key = '${_quizTypesKey}_$subjectId';
    if (!forceRefresh &&
        _cachedQuizTypes.containsKey(subjectId) &&
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
        forceRefresh: forceRefresh,
      );

      _cachedQuizTypes[subjectId] = {key: quizTypes};
      _logger.i('과목 $subjectId에 대한 퀴즈 타입을 가져왔습니다: ${quizTypes.length}');
      _logger.d(
          'Retrieved quiz types: ${quizTypes.map((qt) => qt.name).join(', ')}');
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
  Future<List<Quiz>> getQuizzes(String subjectId, String quizTypeId,
      {bool forceRefresh = false}) async {
    _logger.i('과목 $subjectId에 대한 퀴즈 가져오는 중입니다: $quizTypeId');

    // 캐시 키 생성
    final key = '${_quizzesKey}_${subjectId}_$quizTypeId';

    // 캐시에서 퀴즈가 존재하는지 확인
    if (!forceRefresh &&
        _cachedQuizzes.containsKey(subjectId) &&
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
          // Firestore에서 퀴즈 데이터를 가져옴
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
        // 캐시된 데이터 파싱 방
        parseData: (data) => (json.decode(data) as List)
            .map((item) => Quiz.fromJson(item as Map<String, dynamic>))
            .toList(),
        // 퀴즈 데이터를 JSON으로 인코딩
        encodeData: (quizzes) =>
            json.encode(quizzes.map((q) => q.toJson()).toList()),
        forceRefresh: forceRefresh,
      );

      // 캐시에 퀴즈 데이터 저장
      _cachedQuizzes[subjectId] = {
        quizTypeId: {key: quizzes}
      };
      _logger.i(
          '과목 $subjectId 및 퀴즈 유형 $quizTypeId에 대한 퀴를 가져왔습니다: ${quizzes.length}');
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
    bool forceRefresh = false,
  }) async {
    _logger.d('캐시를 사용하여 데이터 가져오는 중: $key');
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(key);
    final cacheTimestamp = prefs.getInt('${key}_timestamp');

    if (!forceRefresh && cachedData != null && cacheTimestamp != null) {
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

  Future<String> addQuizTypeToSubject(String subjectId, String typeName) async {
    _logger.i('과목 $subjectId에 퀴즈 유형 추가 중: $typeName');
    try {
      final quizTypeId = _uuid.v4();
      final quizTypeData = {
        'id': quizTypeId,
        'name': typeName,
      };

      // subjects 컬렉션 내의 특정 문서(subjectId)의 quizTypes 하위 컬렉션에 새 문서 추가
      await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('quizTypes')
          .doc(quizTypeId)
          .set(quizTypeData);

      // 캐시 업데이트
      _cachedQuizTypes[subjectId] ??= {};
      _cachedQuizTypes[subjectId]!['${_quizTypesKey}_$subjectId'] ??= [];
      _cachedQuizTypes[subjectId]!['${_quizTypesKey}_$subjectId']!.add(
        QuizType(id: quizTypeId, name: typeName, subjectId: subjectId),
      );

      // SharedPreferences 업데이트
      await _updateSharedPreferences(subjectId, quizTypeId);

      _logger.i('과목 $subjectId에 퀴즈 유형을 추가했습니다: $quizTypeId');
      return quizTypeId;
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

      // 수정: 캐 업데이트 로직 개선
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
    _logger.i('메모리 캐시를 새로고침하는 중입다');
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
    try {
      // Clear the cache for this subject
      _cachedQuizTypes.remove(subjectId);
      _cachedQuizzes.remove(subjectId);

      await getSubjects();
      await getQuizTypes(subjectId);

      // ... rest of the method
    } catch (e) {
      _logger.e('과목 $subjectId의 데이터를 새로고침하는 중 오류가 발생했습니다: $e');
      rethrow;
    }
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

  // type별 퀴즈 수 가져오기
  Future<int> getTotalQuizCount(String subjectId, String quizTypeId) async {
    try {
      final querySnapshot = await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('quizTypes')
          .doc(quizTypeId)
          .collection('quizzes')
          .get();
      return querySnapshot.docs.length;
    } catch (e) {
      _logger.e('퀴즈 수를 가져오는 중 오류 발생: $e');
      return 0;
    }
  }
}
