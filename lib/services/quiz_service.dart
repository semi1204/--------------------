import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/subject.dart';
import '../models/quiz_type.dart';
import '../models/quiz.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  static const String _subjectsKey = 'subjects';
  static const String _quizTypesKey = 'quizTypes';
  static const String _quizzesKey = 'quizzes';
  static const String _userQuizDataKey = 'userQuizData';

  // 수정: 초기 간격을 4320분(3일)로 설정
  static const int _initialInterval = 4320;

  // 추가: 개발 환경을 위한 짧은 시간 옵션
  static const bool _useShortIntervals = kDebugMode;
  static const int _debugInitialInterval = 60; // 1분

  Future<void> updateUserQuizData(
      String userId, String quizId, bool isCorrect) async {
    _logger.i('Updating user quiz data for user: $userId, quiz: $quizId');
    final prefs = await SharedPreferences.getInstance();
    final userData = await getUserQuizData(userId);

    if (!userData.containsKey(quizId)) {
      userData[quizId] = {
        'correct': 0,
        'total': 0,
        'nextReviewDate': DateTime.now()
            .add(Duration(
                minutes: _useShortIntervals
                    ? _debugInitialInterval
                    : _initialInterval))
            .toIso8601String(),
        'accuracy': 0.0,
        'interval':
            _useShortIntervals ? _debugInitialInterval : _initialInterval,
        'consecutiveCorrect': 0,
      };
    }

    userData[quizId]['total']++;
    if (isCorrect) {
      userData[quizId]['correct']++;
      userData[quizId]['consecutiveCorrect']++;
    } else {
      userData[quizId]['consecutiveCorrect'] = 0;
    }

    userData[quizId]['accuracy'] =
        (userData[quizId]['correct'] / userData[quizId]['total']).toDouble();

    final now = DateTime.now();
    if (isCorrect) {
      // 수정: 정답 시 간격 증가 로직
      double multiplier =
          2.0 + (userData[quizId]['consecutiveCorrect'] - 1) * 0.5;
      multiplier = multiplier.clamp(2.0, 3.5); // 최대 3.5배로 제한
      int newInterval =
          (userData[quizId]['interval'] as int) * multiplier.round();
      userData[quizId]['interval'] = newInterval;
      userData[quizId]['nextReviewDate'] =
          now.add(Duration(minutes: newInterval)).toIso8601String();
    } else {
      // 수정: 오답 시 간격 감소 로직
      int newInterval = (userData[quizId]['interval'] as int) ~/ 2;
      userData[quizId]['interval'] = newInterval;
      userData[quizId]['nextReviewDate'] =
          now.add(Duration(minutes: newInterval)).toIso8601String();
    }

    _logger.i(
        'Next review interval set to ${userData[quizId]['interval']} minutes');

    await prefs.setString('${_userQuizDataKey}_$userId', json.encode(userData));

    // Firestore update
    await _firestore
        .collection('users')
        .doc(userId)
        .set({'quizData': userData}, SetOptions(merge: true));

    _logger.i(
        'User quiz data updated successfully. New accuracy: ${userData[quizId]['accuracy']}, Next review: ${userData[quizId]['nextReviewDate']}');
  }

  Future<Map<String, dynamic>> getUserQuizData(String userId) async {
    _logger.i('Fetching user quiz data for user: $userId');
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('${_userQuizDataKey}_$userId');
    if (userData != null) {
      return json.decode(userData);
    }
    return {};
  }

  Stream<List<Quiz>> getIncorrectQuizzes(
      String userId, String subjectId) async* {
    _logger
        .i('Fetching incorrect quizzes for user: $userId, subject: $subjectId');
    final userData = await getUserQuizData(userId);
    final now = DateTime.now();

    await for (var snapshot in _firestore
        .collection('subjects')
        .doc(subjectId)
        .collection('quizTypes')
        .snapshots()) {
      List<Quiz> incorrectQuizzes = [];
      for (var quizTypeDoc in snapshot.docs) {
        var quizSnapshot =
            await quizTypeDoc.reference.collection('quizzes').get();
        for (var quizDoc in quizSnapshot.docs) {
          final quiz = Quiz.fromFirestore(quizDoc);
          final quizData = userData[quiz.id];
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
      _logger.i(
          'Yielding ${incorrectQuizzes.length} incorrect quizzes for review');
      yield incorrectQuizzes;
    }
  }

  Stream<List<Subject>> getSubjects() async* {
    _logger.i('Fetching subjects');

    // Try to get subjects from cache
    final prefs = await SharedPreferences.getInstance();
    final cachedSubjects = prefs.getString(_subjectsKey);

    if (cachedSubjects != null) {
      _logger.i('Subjects fetched from cache');
      yield (json.decode(cachedSubjects) as List)
          .map((item) => Subject.fromMap(item))
          .toList();
    }

    // Fetch from Firestore and update cache
    await for (var snapshot in _firestore.collection('subjects').snapshots()) {
      final subjects =
          snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList();
      _logger.i('Subjects fetched from Firestore. Count: ${subjects.length}');

      // Update cache
      await prefs.setString(_subjectsKey,
          json.encode(subjects.map((s) => s.toFirestore()).toList()));

      yield subjects;
    }
  }

  Stream<List<QuizType>> getQuizTypes(String subjectId) async* {
    _logger.i('Fetching quiz types for subject: $subjectId');

    // Try to get quiz types from cache
    final prefs = await SharedPreferences.getInstance();
    final cachedQuizTypes = prefs.getString('${_quizTypesKey}_$subjectId');

    if (cachedQuizTypes != null) {
      _logger.i('Quiz types fetched from cache');
      yield (json.decode(cachedQuizTypes) as List)
          .map((item) => QuizType.fromMap(item))
          .toList();
    }

    // Fetch from Firestore and update cache
    await for (var snapshot in _firestore
        .collection('subjects')
        .doc(subjectId)
        .collection('quizTypes')
        .snapshots()) {
      final quizTypes =
          snapshot.docs.map((doc) => QuizType.fromFirestore(doc)).toList();
      _logger
          .i('Quiz types fetched from Firestore. Count: ${quizTypes.length}');

      // Update cache
      await prefs.setString('${_quizTypesKey}_$subjectId',
          json.encode(quizTypes.map((qt) => qt.toFirestore()).toList()));

      yield quizTypes;
    }
  }

  Future<void> addQuizTypeToSubject(String subjectId, String typeName) async {
    _logger.i('Adding new quiz type: $typeName to subject: $subjectId');
    try {
      final quizTypeId = Uuid().v4();
      await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('quizTypes')
          .doc(quizTypeId)
          .set({'name': typeName, 'id': quizTypeId});
      _logger.i('Quiz type added successfully to subject');
    } catch (e) {
      _logger.e('Error adding quiz type to subject: $e');
      rethrow;
    }
  }

  Stream<List<QuizType>> getQuizTypesForSubject(String subjectId) {
    return _firestore
        .collection('subjects')
        .doc(subjectId)
        .collection('quizTypes')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => QuizType.fromFirestore(doc)).toList();
    });
  }

  Future<void> addSubject(String name) async {
    _logger.i('Adding new subject: $name');
    try {
      await _firestore.collection('subjects').add({'name': name});
      _logger.i('Subject added successfully');
    } catch (e) {
      _logger.e('Error adding subject: $e');
      rethrow;
    }
  }

  Stream<List<Quiz>> getQuizzes(String subjectId, String quizTypeId) async* {
    _logger
        .i('Fetching quizzes for subject: $subjectId, quizType: $quizTypeId');

    // Try to get quizzes from cache
    final prefs = await SharedPreferences.getInstance();
    final cachedQuizzes =
        prefs.getString('${_quizzesKey}_${subjectId}_$quizTypeId');

    if (cachedQuizzes != null) {
      _logger.i('Quizzes fetched from cache');
      yield (json.decode(cachedQuizzes) as List)
          .map((item) => Quiz.fromMap(item))
          .toList();
    }

    // Fetch from Firestore and update cache
    await for (var snapshot in _firestore
        .collection('subjects')
        .doc(subjectId)
        .collection('quizTypes')
        .doc(quizTypeId)
        .collection('quizzes')
        .snapshots()) {
      final quizzes =
          snapshot.docs.map((doc) => Quiz.fromFirestore(doc)).toList();
      _logger.i('Quizzes fetched from Firestore. Count: ${quizzes.length}');

      // Update cache
      await prefs.setString('${_quizzesKey}_${subjectId}_$quizTypeId',
          json.encode(quizzes.map((q) => q.toFirestore()).toList()));

      yield quizzes;
    }
  }

  Future<void> addQuiz(String subjectId, String quizTypeId, Quiz quiz) async {
    _logger.i('Adding new quiz to subject: $subjectId, quizType: $quizTypeId');
    try {
      await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('quizTypes')
          .doc(quizTypeId)
          .collection('quizzes')
          .add(quiz.toFirestore());
      _logger.i('Quiz added successfully');

      // Update cache
      final prefs = await SharedPreferences.getInstance();
      final cachedQuizzes =
          prefs.getString('${_quizzesKey}_${subjectId}_$quizTypeId');
      if (cachedQuizzes != null) {
        final List<dynamic> quizzes = json.decode(cachedQuizzes);
        quizzes.add(quiz.toFirestore());
        await prefs.setString(
            '${_quizzesKey}_${subjectId}_$quizTypeId', json.encode(quizzes));
      }
    } catch (e) {
      _logger.e('Error adding quiz: $e');
      rethrow;
    }
  }

  Future<void> updateQuiz(
      String subjectId, String quizTypeId, Quiz quiz) async {
    _logger.i('Updating quiz: ${quiz.id}');
    try {
      await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('quizTypes')
          .doc(quizTypeId)
          .collection('quizzes')
          .doc(quiz.id)
          .update(quiz.toFirestore());
      _logger.i('Quiz updated successfully');

      // Update cache
      final prefs = await SharedPreferences.getInstance();
      final cachedQuizzes =
          prefs.getString('${_quizzesKey}_${subjectId}_$quizTypeId');
      if (cachedQuizzes != null) {
        final List<dynamic> quizzes = json.decode(cachedQuizzes);
        final index = quizzes.indexWhere((q) => q['id'] == quiz.id);
        if (index != -1) {
          quizzes[index] = quiz.toFirestore();
          await prefs.setString(
              '${_quizzesKey}_${subjectId}_$quizTypeId', json.encode(quizzes));
        }
      }
    } catch (e) {
      _logger.e('Error updating quiz: $e');
      rethrow;
    }
  }

  Future<void> deleteQuiz(
      String subjectId, String quizTypeId, String quizId) async {
    _logger.i('Deleting quiz: $quizId');
    try {
      await _firestore
          .collection('subjects')
          .doc(subjectId)
          .collection('quizTypes')
          .doc(quizTypeId)
          .collection('quizzes')
          .doc(quizId)
          .delete();
      _logger.i('Quiz deleted successfully');

      // Update cache
      final prefs = await SharedPreferences.getInstance();
      final cachedQuizzes =
          prefs.getString('${_quizzesKey}_${subjectId}_$quizTypeId');
      if (cachedQuizzes != null) {
        final List<dynamic> quizzes = json.decode(cachedQuizzes);
        quizzes.removeWhere((q) => q['id'] == quizId);
        await prefs.setString(
            '${_quizzesKey}_${subjectId}_$quizTypeId', json.encode(quizzes));
      }
    } catch (e) {
      _logger.e('Error deleting quiz: $e');
      rethrow;
    }
  }
}
