import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class Quiz {
  final String id;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final String typeId;
  final List<String> keywords; // Changed from String? to List<String>

  final Logger _logger = Logger();

  Quiz({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    required this.typeId,
    this.keywords = const [], // Default to empty list
  }) {
    _logger.d('Quiz object created with keywords: $keywords');
  }

  factory Quiz.fromFirestore(DocumentSnapshot doc) {
    final logger = Logger();
    Map data = doc.data() as Map<String, dynamic>;
    logger.d('Creating Quiz from Firestore data: $data');
    return Quiz(
      id: doc.id,
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctOptionIndex: data['correctOptionIndex'] ?? 0,
      explanation: data['explanation'] ?? '',
      typeId: data['typeId'] ?? '',
      keywords: List<String>.from(
          data['keywords'] ?? []), // Parse keywords as List<String>
    );
  }

  Map<String, dynamic> toFirestore() {
    _logger.d('Converting Quiz to Firestore data');
    return {
      'question': question,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
      'typeId': typeId,
      'keywords': keywords, // Always include keywords (empty list if none)
    };
  }
}
