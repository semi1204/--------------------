import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Stream<List<Subject>> getSubjects() {
  //   _logger.i('Fetching subjects');
  //   return _firestore.collection('subjects').snapshots().map((snapshot) {
  //     _logger.i('Subjects fetched. Count: ${snapshot.docs.length}');
  //     return snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList();
  //   });
  // }

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
