import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class Quiz {
  final String id;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final String typeId;
  final List<String> keywords;
  final String? imageUrl;

  final Logger _logger = Logger();

  Quiz({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    required this.typeId,
    this.keywords = const [],
    this.imageUrl,
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
      imageUrl: data['imageUrl'],
    );
  }

  // Add this method for caching
  factory Quiz.fromMap(Map<String, dynamic> map) {
    return Quiz(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctOptionIndex: map['correctOptionIndex'] ?? 0,
      explanation: map['explanation'] ?? '',
      typeId: map['typeId'] ?? '',
      keywords: List<String>.from(map['keywords'] ?? []),
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    _logger.d('Converting Quiz to Firestore data with Markdown support');
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
      'typeId': typeId,
      'keywords': keywords,
      'imageUrl': imageUrl,
    };
  }
}
