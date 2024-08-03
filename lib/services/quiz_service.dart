import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subject.dart';
import '../models/quiz_type.dart';
import '../models/quiz.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class QuizService {
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  static const String _subjectsKey = 'subjects';
  static const String _quizTypesKey = 'quizTypes';
  static const String _quizzesKey = 'quizzes';
  static const String _userQuizDataKey = 'userQuizData';
  static const Duration _cacheExpiration = Duration(hours: 1);

  QuizService._internal();

  // 수정: 캐시 데이터 타입을 Map으로 변경하여 효율적인 데이터 접근 가능
  final Map<String, List<Subject>> _cachedSubjects = {};
  final Map<String, Map<String, List<QuizType>>> _cachedQuizTypes = {};
  final Map<String, Map<String, Map<String, List<Quiz>>>> _cachedQuizzes = {};

  Future<List<Quiz>> getIncorrectQuizzes(
      String userId, String subjectId) async {
    _logger
        .i('Fetching incorrect quizzes for user: $userId, subject: $subjectId');
    final userData = await getUserQuizData(userId);
    final now = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    final deletedQuizzes =
        Set.from(prefs.getStringList('deleted_quizzes_$userId') ?? []);

    List<Quiz> incorrectQuizzes = [];

    try {
      // 수정: await 사용
      final quizTypes = await getQuizTypes(subjectId);
      for (var quizType in quizTypes) {
        // 수정: await 사용
        final quizzes = await getQuizzes(subjectId, quizType.id);
        for (var quiz in quizzes) {
          if (!deletedQuizzes.contains(quiz.id)) {
            final quizData = userData[subjectId]?[quizType.id]?[quiz.id];
            if (quizData != null) {
              final accuracy = quizData['accuracy'] ?? 0.0;
              final nextReviewDate = DateTime.parse(quizData['nextReviewDate']);
              if (accuracy < 1.0 && now.isAfter(nextReviewDate)) {
                incorrectQuizzes.add(quiz);
                _logger.d('Added incorrect quiz: ${quiz.id} to review list');
              }
            }
          }
        }
      }

      _logger
          .i('Fetched ${incorrectQuizzes.length} incorrect quizzes for review');
      return incorrectQuizzes;
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
}
