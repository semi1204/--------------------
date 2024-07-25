// quiz_service.dart
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
        .collection('quizTypes')
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snapshot) {
      _logger.i('Quiz types fetched. Count: ${snapshot.docs.length}');
      return snapshot.docs.map((doc) => QuizType.fromFirestore(doc)).toList();
    });
  }

  Future<void> addQuizTypeToSubject(String subjectId, String typeName) async {
    _logger.i('Adding new quiz type: $typeName to subject: $subjectId');
    try {
      final subjectRef = _firestore.collection('subjects').doc(subjectId);
      await subjectRef.update({
        'quizTypes': FieldValue.arrayUnion([
          {'name': typeName, 'id': Uuid().v4()}
        ])
      });
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
        .snapshots()
        .map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final quizTypes = data['quizTypes'] as List<dynamic>? ?? [];
      return quizTypes.map((type) => QuizType.fromMap(type)).toList();
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

  Future<void> addQuizType(String name, String subjectId) async {
    _logger.i('Adding new quiz type: $name for subject: $subjectId');
    try {
      await _firestore.collection('quizTypes').add({
        'name': name,
        'subjectId': subjectId,
      });
      _logger.i('Quiz type added successfully');
    } catch (e) {
      _logger.e('Error adding quiz type: $e');
      rethrow;
    }
  }

  Stream<List<Quiz>> getQuizzes(String typeId) {
    _logger.i('Fetching quizzes for type: $typeId');
    return _firestore
        .collection('quizzes')
        .where('typeId', isEqualTo: typeId)
        .snapshots()
        .map((snapshot) {
      _logger.i('Quizzes fetched. Count: ${snapshot.docs.length}');
      return snapshot.docs.map((doc) => Quiz.fromFirestore(doc)).toList();
    });
  }

  Future<void> addQuiz(Quiz quiz) async {
    _logger.i('Adding new quiz');
    try {
      await _firestore.collection('quizzes').add(quiz.toFirestore());
      _logger.i('Quiz added successfully');
    } catch (e) {
      _logger.e('Error adding quiz: $e');
      rethrow;
    }
  }
}
