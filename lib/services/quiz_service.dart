import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nursing_quiz_app_6/utils/anki_algorithm.dart';
import '../models/subject.dart';
import '../models/quiz_type.dart';
import '../models/quiz.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart'; // Add this import

class QuizService {
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  static const String _subjectsKey = 'subjects'; // 주제데이터의 키
  static const String _quizTypesKey = 'quizTypes'; // 퀴즈 타입 데이터의 키
  static const String _quizzesKey = 'quizzes'; // 퀴즈 데이터의 키
  static const String _userQuizDataKey = 'userQuizData'; // 사용자 퀴즈 데이터의 키
  static const Duration _cacheExpiration = Duration(hours: 1); // 캐시 만료 시간

  QuizService._internal();

  // 수정: 캐시 데이터 타입을 Map으로 변경하여 효율적인 데이터 접근 가능
  final Map<String, List<Subject>> _cachedSubjects = {}; // 캐시된 주제 데이터를 저장하는 맵
  final Map<String, Map<String, List<QuizType>>> _cachedQuizTypes =
      {}; // 캐시된 퀴즈 타입 데이터를 저장하는 맵
  final Map<String, Map<String, Map<String, List<Quiz>>>> _cachedQuizzes =
      {}; // 캐시된 주제 데이터를 저장하는 맵

  Future<List<Quiz>> getIncorrectQuizzes(
      String userId, String subjectId) async {
    _logger
        .i('Fetching incorrect quizzes for user: $userId, subject: $subjectId');
    final userData = await getUserQuizData(userId); // 사용자 퀴즈 데이터를 가져옴
    final now = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    final deletedQuizzes =
        Set.from(prefs.getStringList('deleted_quizzes_$userId') ?? []);
    _logger.d('Deleted quizzes: $deletedQuizzes'); // 삭제된 퀴즈 목록을 가져옴

    List<Quiz> incorrectQuizzes = []; // 틀린 퀴즈 목록 초기화

    try {
      final quizTypes = await getQuizTypes(subjectId);
      _logger.d(
          'Quiz types for subject $subjectId: ${quizTypes.map((qt) => qt.id).toList()}'); // 주제의 퀴즈 타입을 가져옴
      for (var quizType in quizTypes) {
        final quizzes = await getQuizzes(subjectId, quizType.id);
        _logger.d(
            'Fetched ${quizzes.length} quizzes for quiz type: ${quizType.id}'); // 퀴즈 목록을 가져옴
        for (var quiz in quizzes) {
          if (!deletedQuizzes.contains(quiz.id)) {
            // 퀴즈가 삭제된 목록에 없을 경우
            final quizData =
                userData[subjectId]?[quizType.id]?[quiz.id]; // 퀴즈 데이터를 가져옴
            if (quizData != null) {
              final accuracy = quizData['accuracy'] ?? 0.0; // 정확도
              final nextReviewDate =
                  DateTime.parse(quizData['nextReviewDate']); // 다음 리뷰 날짜
              if (accuracy < 1.0 && now.isAfter(nextReviewDate)) {
                // 정확도가 100% 미만이고, 복습 날짜가 지났을 경우
                incorrectQuizzes.add(quiz); // 틀린 퀴즈 목록에 추가
                _logger.d('Added incorrect quiz: ${quiz.id} to review list');
              } else {
                _logger.d(
                    'Quiz ${quiz.id} not added to review list. Reason: ${accuracy >= 1.0 ? "Perfect accuracy" : "Review date in future"}');
              }
            } else {
              _logger.d('No data found for quiz: ${quiz.id}');
            }
          }
        }
      }
      // 실수 횟수에 따라 틀린 퀴즈를 정렬 (내림차순)
      incorrectQuizzes.sort((a, b) {
        final aMistakeCount =
            userData[subjectId]?[a.typeId]?[a.id]?['mistakeCount'] ?? 0;
        final bMistakeCount =
            userData[subjectId]?[b.typeId]?[b.id]?['mistakeCount'] ?? 0;
        return bMistakeCount.compareTo(aMistakeCount);
      });

      _logger
          .i('Fetched ${incorrectQuizzes.length} incorrect quizzes for review');
      return incorrectQuizzes; // 틀린 퀴즈 목록 반환
    } catch (e) {
      _logger.e('Error fetching incorrect quizzes: $e');
      rethrow;
    }
  }

  // 수정: 제네릭 타입을 사용하여 코드 재사용성 향상
  Future<T> _getDataWithCache<T>({
    required String key,
    required Future<T> Function() fetchFromFirestore,
    required T Function(String) parseData,
    required String Function(T) encodeData,
  }) async {
    _logger.d('Attempting to get data with cache for key: $key');
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(key);
    final cacheTimestamp = prefs.getInt('${key}_timestamp');

    if (cachedData != null && cacheTimestamp != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - cacheTimestamp < _cacheExpiration.inMilliseconds) {
        _logger.d('Data fetched from cache for key: $key');
        return parseData(cachedData);
      }
    }

    final data = await fetchFromFirestore();
    final jsonData = encodeData(data);
    await prefs.setString(key, jsonData);
    await prefs.setInt(
        '${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
    _logger.d('Data fetched from Firestore and cached for key: $key');
    return data;
  }

  Future<Map<String, dynamic>> getUserQuizData(String userId) async {
    return _getDataWithCache(
      key: '${_userQuizDataKey}_$userId',
      fetchFromFirestore: () async {
        final doc = await _firestore.collection('users').doc(userId).get();
        return doc.data()?['quizData'] ?? {};
      },
      parseData: (data) => json.decode(data),
      encodeData: (data) => json.encode(data),
    );
  }

  // Future를 반환하도록 변경하여 일관성 유지
  Future<List<Subject>> getSubjects() async {
    _logger.i('Fetching subjects');
    const key = _subjectsKey;
    if (_cachedSubjects.containsKey(key)) {
      _logger.d('Subjects fetched from memory cache');
      return _cachedSubjects[key]!;
    }

    try {
      final subjects = await _getDataWithCache<List<Subject>>(
        key: key,
        fetchFromFirestore: () async {
          _logger.d('Fetching subjects from Firestore');
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
      _logger.i('Fetched ${subjects.length} subjects');
      return subjects;
    } catch (e) {
      _logger.e('Error fetching subjects: $e');
      rethrow;
    }
  }

  // 수정: Stream 대신 Future를 반환하도록 변경
  Future<List<QuizType>> getQuizTypes(String subjectId) async {
    _logger.i('Fetching quiz types for subject: $subjectId');
    final key = '${_quizTypesKey}_$subjectId';
    if (_cachedQuizTypes.containsKey(subjectId) &&
        _cachedQuizTypes[subjectId]!.containsKey(key)) {
      _logger.d('Quiz types fetched from memory cache for subject: $subjectId');
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
      _logger
          .i('Fetched ${quizTypes.length} quiz types for subject: $subjectId');
      return quizTypes;
    } catch (e) {
      _logger.e('Error fetching quiz types: $e');
      rethrow;
    }
  }

  // 수정: Stream 대신 Future를 반환하도록 변경
  Future<List<Quiz>> getQuizzes(String subjectId, String quizTypeId) async {
    _logger
        .i('Fetching quizzes for subject: $subjectId, quizType: $quizTypeId');
    final key = '${_quizzesKey}_${subjectId}_$quizTypeId';
    if (_cachedQuizzes.containsKey(subjectId) &&
        _cachedQuizzes[subjectId]!.containsKey(quizTypeId) &&
        _cachedQuizzes[subjectId]![quizTypeId]!.containsKey(key)) {
      _logger.d(
          'Quizzes fetched from memory cache for subject: $subjectId, quizType: $quizTypeId');
      return _cachedQuizzes[subjectId]![quizTypeId]![key]!;
    }

    try {
      final quizzes = await _getDataWithCache<List<Quiz>>(
        key: key,
        fetchFromFirestore: () async {
          final snapshot = await _firestore
              .collection('subjects')
              .doc(subjectId)
              .collection('quizTypes')
              .doc(quizTypeId)
              .collection('quizzes')
              .get();
          return snapshot.docs.map((doc) => Quiz.fromFirestore(doc)).toList();
        },
        parseData: (data) => (json.decode(data) as List)
            .map((item) => Quiz.fromJson(item as Map<String, dynamic>))
            .toList(),
        encodeData: (quizzes) =>
            json.encode(quizzes.map((q) => q.toJson()).toList()),
      );

      _cachedQuizzes[subjectId] = {
        quizTypeId: {key: quizzes}
      };
      _logger.i(
          'Fetched ${quizzes.length} quizzes for subject: $subjectId, quizType: $quizTypeId');
      return quizzes;
    } catch (e) {
      _logger.e('Error fetching quizzes: $e');
      rethrow;
    }
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

      _logger.i('Quiz type added successfully to subject: $subjectId');
    } catch (e) {
      _logger.e('Error adding quiz type to subject: $e');
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

      _logger.i('Subject added successfully: ${newSubject.name}');
    } catch (e) {
      _logger.e('Error adding subject: $e');
      rethrow;
    }
  }

  Future<void> addQuiz(String subjectId, String quizTypeId, Quiz quiz) async {
    _logger.i('Adding new quiz to subject: $subjectId, quizType: $quizTypeId');
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

      _logger.i('Quiz added successfully with ID: ${docRef.id}');

      final updatedQuiz = Quiz(
        id: docRef.id,
        question: quiz.question,
        options: quiz.options,
        correctOptionIndex: quiz.correctOptionIndex,
        explanation: quiz.explanation,
        typeId: quiz.typeId,
        keywords: quiz.keywords,
        imageUrl: quizData['imageUrl'],
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
      _logger.e('Error adding quiz: $e');
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

      _logger.i('Quiz updated successfully with ID: ${quiz.id}');

      // 캐시 데이터를 SharedPreferences에 저장
      await _updateSharedPreferences(subjectId, quizTypeId);
    } catch (e) {
      _logger.e('Error updating quiz: $e');
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

      _logger.i('Quiz deleted successfully: $quizId');

      // 캐시 데이터를 SharedPreferences에 저장
      await _updateSharedPreferences(subjectId, quizTypeId);
    } catch (e) {
      _logger.e('Error deleting quiz: $e');
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

  // 사용자 퀴즈 데이터를 업데이트하는 메소드
  Future<void> updateUserQuizData(String userId, String subjectId,
      String quizTypeId, String quizId, bool isCorrect,
      {Duration? answerTime, int? selectedOptionIndex}) async {
    // 새로 추가: answerTime 및 selectedOptionIndex 매개변수
    if (userId.isEmpty) {
      _logger.w('Attempted to update quiz data for empty user ID');
      return;
    }

    _logger.i(
        'Updating user quiz data: userId=$userId, subjectId=$subjectId, quizTypeId=$quizTypeId, quizId=$quizId, isCorrect=$isCorrect, selectedOptionIndex=$selectedOptionIndex');

    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        _logger.i('Device is offline. Saving data locally.');
        await _saveOfflineQuizData(userId, subjectId, quizTypeId, quizId,
            isCorrect, selectedOptionIndex);
        return;
      }

      final userDocRef = // 사용자 문서 참조
          FirebaseFirestore.instance.collection('users').doc(userId);
      final userDoc = await userDocRef.get(); // 사용자 문서 가져오기

      if (!userDoc.exists) {
        await userDocRef.set({'quizData': {}}); // 사용자 문서가 없을 경우 생성
      }

      final quizDataPath =
          'quizData.$subjectId.$quizTypeId.$quizId'; // 퀴즈 데이터 경로
      final quizData = userDoc.data()?['quizData']?[subjectId]?[quizTypeId]
              ?[quizId] ??
          {}; // 퀴즈 데이터 가져오기

      int correct = quizData['correct'] ?? 0; // 정답 수
      int total = quizData['total'] ?? 0; // 전체 퀴즈 수
      int consecutiveCorrect = quizData['consecutiveCorrect'] ?? 0; // 연속 정답 수
      int interval = quizData['interval'] ?? 1; // 간격
      double easeFactor = quizData['easeFactor'] ?? 2.5; // 용이성 계수
      int mistakeCount = quizData['mistakeCount'] ?? 0; // 실수 횟수

      total++;
      if (isCorrect) {
        correct++;
        consecutiveCorrect++;
      } else {
        consecutiveCorrect = 0;
        mistakeCount++;
      }

      double accuracy = correct / total;

      int? qualityOfRecall;
      if (answerTime != null) {
        qualityOfRecall =
            AnkiAlgorithm.evaluateRecallQuality(answerTime, isCorrect);
      }

      final ankiResult = AnkiAlgorithm.calculateNextReview(
        interval: interval,
        easeFactor: easeFactor,
        consecutiveCorrect: consecutiveCorrect,
        isCorrect: isCorrect,
        qualityOfRecall: qualityOfRecall,
        mistakeCount: mistakeCount,
      );

      final now = DateTime.now();
      final nextReviewDate =
          now.add(Duration(days: ankiResult['interval'] as int));

      await userDocRef.update({
        '$quizDataPath.correct': correct,
        '$quizDataPath.total': total,
        '$quizDataPath.accuracy': accuracy,
        '$quizDataPath.interval': (ankiResult['interval'] as num).toInt(),
        '$quizDataPath.easeFactor': ankiResult['easeFactor'] as double,
        '$quizDataPath.consecutiveCorrect':
            (ankiResult['consecutiveCorrect'] as num).toInt(),
        '$quizDataPath.nextReviewDate': nextReviewDate.toIso8601String(),
        '$quizDataPath.mistakeCount': ankiResult['mistakeCount'],
        '$quizDataPath.lastAnswered': now.toIso8601String(),
        '$quizDataPath.selectedOptionIndex': selectedOptionIndex,
      });

      _logger.i('User quiz data updated successfully');
    } catch (e) {
      _logger.e('Error updating user quiz data: $e');
      rethrow;
    }
  }

  // method for offline support
  Future<void> _saveOfflineQuizData(
      String userId,
      String subjectId,
      String quizTypeId,
      String quizId,
      bool isCorrect,
      int? selectedOptionIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final offlineData = prefs.getString('offline_quiz_data') ?? '{}';
    final decodedData = json.decode(offlineData) as Map<String, dynamic>;

    if (!decodedData.containsKey(userId)) {
      decodedData[userId] = {};
    }
    if (!decodedData[userId].containsKey(subjectId)) {
      decodedData[userId][subjectId] = {};
    }
    if (!decodedData[userId][subjectId].containsKey(quizTypeId)) {
      decodedData[userId][subjectId][quizTypeId] = {};
    }

    decodedData[userId][subjectId][quizTypeId][quizId] = {
      'isCorrect': isCorrect,
      'selectedOptionIndex': selectedOptionIndex,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await prefs.setString('offline_quiz_data', json.encode(decodedData));
    _logger.i('Offline quiz data saved successfully');
  }

  Future<void> clearCache() async {
    _logger.i('Clearing all cached quiz data');
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_subjectsKey) ||
          key.startsWith(_quizTypesKey) ||
          key.startsWith(_quizzesKey) ||
          key.startsWith(_userQuizDataKey)) {
        await prefs.remove(key);
      }
    }
    _cachedSubjects.clear();
    _cachedQuizTypes.clear();
    _cachedQuizzes.clear();
    _logger.i('Cache cleared successfully');
  }

  // 새로 추가: 메모리 캐시 새로고침 메서드
  Future<void> refreshCache() async {
    _logger.i('Refreshing memory cache');
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
    _logger.i('Memory cache refreshed successfully');
  }

  // 새로 추가: 특정 주제의 퀴즈 타입 및 퀴즈 새로고침 메서드
  Future<void> refreshSubjectData(String subjectId) async {
    _logger.i('Refreshing data for subject: $subjectId');
    _cachedQuizTypes.remove(subjectId);
    _cachedQuizzes.remove(subjectId);

    final quizTypes = await getQuizTypes(subjectId);
    for (final quizType in quizTypes) {
      await getQuizzes(subjectId, quizType.id);
    }
    _logger.i('Data refreshed for subject: $subjectId');
  }

  // New method to generate performance analytics
  Future<Map<String, dynamic>> generatePerformanceAnalytics(
      String userId, String subjectId) async {
    _logger.i(
        'Generating performance analytics for user: $userId, subject: $subjectId');
    try {
      final userData = await getUserQuizData(userId); // 사용자 퀴즈 데이터 가져오기
      final subjectData = userData[subjectId];

      if (subjectData == null) {
        return {
          'error': 'No data available for this subject'
        }; // 주제 데이터가 없을 경우 오류 반환
      }

      int totalQuizzes = 0;
      int totalCorrect = 0;
      int totalMistakes = 0;
      List<Map<String, dynamic>> quizTypePerformance = [];
      List<Map<String, dynamic>> recentPerformance = [];

      subjectData.forEach((quizTypeId, quizzes) {
        if (quizzes is Map<String, dynamic>) {
          int quizTypeTotal = 0;
          int quizTypeCorrect = 0;
          int quizTypeMistakes = 0;

          quizzes.forEach((quizId, quizData) {
            if (quizData is Map<String, dynamic>) {
              quizTypeTotal += (quizData['total'] as num?)?.toInt() ?? 0;
              quizTypeCorrect += (quizData['correct'] as num?)?.toInt() ?? 0;
              quizTypeMistakes +=
                  (quizData['mistakeCount'] as num?)?.toInt() ?? 0;

              // recent performance data
              recentPerformance.add({
                'quizId': quizId,
                'lastAnswered': quizData['lastAnswered'] as String? ?? '',
                'isCorrect': (quizData['correct'] as num?) ==
                    (quizData['total'] as num?),
              });
            }
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
        }
      });

      // Sort recent performance by date and limit to last 10 entries
      recentPerformance.sort((a, b) => DateTime.parse(b['lastAnswered'])
          .compareTo(DateTime.parse(a['lastAnswered'])));
      recentPerformance = recentPerformance.take(10).toList();

      return {
        'totalQuizzes': totalQuizzes,
        'totalCorrect': totalCorrect,
        'overallAccuracy':
            totalQuizzes > 0 ? totalCorrect / totalQuizzes : 0, // 전체 정확도
        'totalMistakes': totalMistakes, // 전체 실수 횟수
        'quizTypePerformance': quizTypePerformance, // 퀴즈 타입 성능
        'recentPerformance': recentPerformance, // 최근 성능
      };
    } catch (e) {
      _logger.e('Error generating performance analytics: $e');
      return {'error': 'Failed to generate performance analytics'};
    }
  }
}
