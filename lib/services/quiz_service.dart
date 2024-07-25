import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subject.dart';
import '../models/quiz_type.dart';
import '../models/quiz.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  Stream<List<Subject>> getSubjects() {
    _logger.i('Fetching subjects');
    return _firestore.collection('subjects').snapshots().map((snapshot) {
      _logger.i('Subjects fetched. Count: ${snapshot.docs.length}');
      return snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList();
    });
  }

  Stream<List<QuizType>> getQuizTypes(String subjectId) {
    _logger.i('Fetching quiz types for subject: $subjectId');
    return _firestore
        .collection('subjects')
        .doc(subjectId)
        .collection('quizTypes')
        .snapshots()
        .map((snapshot) {
      _logger.i('Quiz types fetched. Count: ${snapshot.docs.length}');
      return snapshot.docs.map((doc) => QuizType.fromFirestore(doc)).toList();
    });
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

  Stream<List<Quiz>> getQuizzes(String subjectId, String quizTypeId) {
    _logger
        .i('Fetching quizzes for subject: $subjectId, quizType: $quizTypeId');
    return _firestore
        .collection('subjects')
        .doc(subjectId)
        .collection('quizTypes')
        .doc(quizTypeId)
        .collection('quizzes')
        .snapshots()
        .map((snapshot) {
      _logger.i('Quizzes fetched. Count: ${snapshot.docs.length}');
      return snapshot.docs.map((doc) => Quiz.fromFirestore(doc)).toList();
    });
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
    } catch (e) {
      _logger.e('Error adding quiz: $e');
      rethrow;
    }
  }
}
