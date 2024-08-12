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
  final int? year; //year field
  final String? examType;

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
    this.year, // year parameter
    this.examType, // examType parameter
  }) {
    _logger.d('퀴즈 객체 생성');
  }

  Map<String, dynamic> toJson() => toFirestore();

  factory Quiz.fromFirestore(DocumentSnapshot doc, Logger logger) {
    final data = doc.data() as Map<String, dynamic>;
    logger.d('Firestore 데이터에서 퀴즈 생성: $data');

    // imageUrl 처리 로직 개선
    String? imageUrl = data['imageUrl'];
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl =
          'https://firebasestorage.googleapis.com/v0/b/nursingquizapp6.appspot.com/o/$imageUrl?alt=media';
    }
    logger.d('이미지 URL 처리 완료: $imageUrl');

    return Quiz(
      id: doc.id,
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctOptionIndex: data['correctOptionIndex'] ?? 0,
      explanation: data['explanation'] ?? '',
      typeId: data['typeId'] ?? '',
      keywords: List<String>.from(data['keywords'] ?? []),
      imageUrl: imageUrl,
      year: data['year'], // year field
      examType: data['examType'], // examType field
    );
  }

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctOptionIndex: json['correctOptionIndex'] ?? 0,
      explanation: json['explanation'] ?? '',
      typeId: json['typeId'] ?? '',
      keywords: List<String>.from(json['keywords'] ?? []),
      imageUrl: json['imageUrl'],
      year: json['year'], // year field
      examType: json['examType'], // examType field
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
      imageUrl: map['imageUrl'], // Ensure this is included in the map parsing
      year: map['year'], // year field
      examType: map['examType'], // examType field
    );
  }

  Map<String, dynamic> toFirestore() {
    _logger.d('퀴즈 데이터를 Firestore에 변환');
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
      'typeId': typeId,
      'keywords': keywords,
      'imageUrl': imageUrl,
      'year': year, // year field
      'examType': examType, // examType field
    };
  }
}
