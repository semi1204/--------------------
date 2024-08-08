import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subject.dart';
import '../models/quiz_type.dart';
import '../models/quiz.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/user_provider.dart';

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

  Future<List<Quiz>> getQuizzesForReview(String userId, String subjectId,
      String quizTypeId, UserProvider userProvider) async {
    _logger.i(
        'getQuizzesForReview 시작: userId=$userId, subjectId=$subjectId, quizTypeId=$quizTypeId');

    try {
      final userData = userProvider.quizData;
      _logger.d('사용자 데이터 타입: ${userData.runtimeType}');

      final now = DateTime.now();
      // deletedQuizzes를 사용하지 않고 대신 userData에서 확인
      _logger.d('퀴즈 데이터 확인 시작');

      final quizzes = await getQuizzes(subjectId, quizTypeId);
      _logger.d('퀴즈 타입 $quizTypeId에 대해 ${quizzes.length}개의 퀴즈 가져옴');

      List<Quiz> quizzesForReview = [];

      for (var quiz in quizzes) {
        final quizData = userData[subjectId]?[quizTypeId]?[quiz.id];
        if (quizData != null && quizData.isNotEmpty) {
          final accuracy = quizData['accuracy'] ?? 0.0;
          final nextReviewDate = quizData['nextReviewDate'] != null
              ? DateTime.parse(quizData['nextReviewDate'])
              : now;

          if (accuracy < 1.0 && now.isAfter(nextReviewDate)) {
            _logger.d('복습 목록에 추가된 퀴즈: ${quiz.id}');
            quizzesForReview.add(quiz);
          } else {
            _logger.d('복습 목록에 추가되지 않은 퀴즈: ${quiz.id}');
          }
        } else {
          _logger.d('퀴즈 ${quiz.id}에 대한 데이터가 없음. 복습 목록에 추가하지 않음.');
        }
      }

      // 실수 횟수에 따라 틀린 퀴즈를 정렬 (내림차순)
      quizzesForReview.sort((a, b) {
        final aMistakeCount =
            userData[subjectId]?[quizTypeId]?[a.id]?['mistakeCount'] ?? 0;
        final bMistakeCount =
            userData[subjectId]?[quizTypeId]?[b.id]?['mistakeCount'] ?? 0;
        return bMistakeCount.compareTo(aMistakeCount);
      });

      _logger.i('Fetched ${quizzesForReview.length} quizzes for review');
      return quizzesForReview;
    } catch (e) {
      _logger.e('Error fetching quizzes for review: $e');
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

  // 사용자의 퀴즈 데이터를 가져오는 함수
  Future<Map<String, dynamic>> getUserQuizData(String userId) async {
    _logger.i('getUserQuizData 시작: userId=$userId');

    // 캐시를 사용하여 데이터를 가져오는 _getDataWithCache 함수 호출
    final userData = await _getDataWithCache<Map<String, dynamic>>(
      key: '${_userQuizDataKey}_$userId', // 캐시 키 설정
      fetchFromFirestore: () async {
        // Firestore에서 데이터를 가져오는 비동기 함수
        final docSnapshot =
            await _firestore.collection('users').doc(userId).get();
        return docSnapshot.data() ?? {}; // 데이터가 없으면 빈 맵 반환
      },
      parseData: (data) =>
          json.decode(data) as Map<String, dynamic>, // 문자열을 맵으로 파싱
      encodeData: (data) => json.encode(data), // 맵을 JSON 문자열로 인코딩
    );

    _logger.i('사용��� 퀴즈 데이터 로드 완료: ${userData.runtimeType}');
    return userData; // 가져온 사용자 퀴즈 데이터 반환
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

  // 수정: Stream 대신 Future를 반환하록 변경
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
          return snapshot.docs
              .map((doc) => Quiz.fromFirestore(doc, _logger))
              .toList();
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

  // 새로 추가: 특정 주제의 ���즈 타입 및 퀴즈 새로고침 메서드
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

  Future<List<Quiz>> getQuizzesByIds(
      String subjectId, String quizTypeId, List<String> quizIds) async {
    _logger.i(
        'Fetching quizzes by IDs for subject: $subjectId, quizType: $quizTypeId');
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
      _logger.e('Error fetching quizzes by IDs: $e');
      rethrow;
    }
  }

  Future<void> syncUserData(
      String userId, Map<String, dynamic> userData) async {
    _logger.i('Syncing user data for user: $userId');
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'quizData': userData,
      }, SetOptions(merge: true));
      _logger.i('User data synced successfully with Firestore');
    } catch (e) {
      _logger.e('Error syncing user data: $e');
      rethrow;
    }
  }
}
