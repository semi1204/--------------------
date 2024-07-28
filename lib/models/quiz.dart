import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class Quiz {
  final String id;
  final String question; // Now contains Markdown
  final List<String> options;
  final int correctOptionIndex;
  final String explanation; // Now contains Markdown
  final String typeId;
  final List<String> keywords;

  final Logger _logger = Logger();

  Quiz({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    required this.typeId,
    this.keywords = const [],
  }) {
    _logger.d('Quiz object created with Markdown support');
  }

  factory Quiz.fromFirestore(DocumentSnapshot doc) {
    final logger = Logger();
    Map data = doc.data() as Map<String, dynamic>;
    logger.d('Creating Quiz from Firestore data with Markdown support: $data');
    return Quiz(
      id: doc.id,
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctOptionIndex: data['correctOptionIndex'] ?? 0,
      explanation: data['explanation'] ?? '',
      typeId: data['typeId'] ?? '',
      keywords: List<String>.from(data['keywords'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    _logger.d('Converting Quiz to Firestore data with Markdown support');
    return {
      'question': question,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
      'typeId': typeId,
      'keywords': keywords,
    };
  }
}
