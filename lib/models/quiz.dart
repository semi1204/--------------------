// quiz.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:nursing_quiz_app_6/models/keyword.dart';

class Quiz {
  final String id;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final String typeId;
  final List<Keyword> keywords; // String에서 Keyword로 변경
  final String? imageUrl;
  final int? year;
  final String? examType;
  final bool isOX;
  final Logger _logger = Logger();

  Quiz({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    required this.typeId,
    required this.keywords, // 기본값 제거
    this.imageUrl,
    this.year,
    this.examType,
    required this.isOX,
  }) {
    _logger.d('퀴즈 데이터가 마크다운 지원으로 생성');
  }

  // 중앙 변환 메서드
  Map<String, dynamic> _toMap() => {
        'id': id,
        'question': question,
        'options': options,
        'correctOptionIndex': correctOptionIndex,
        'explanation': explanation,
        'typeId': typeId,
        'keywords':
            keywords.map((k) => k.toMap()).toList(), // Keyword 객체를 Map으로 변환
        'imageUrl': imageUrl,
        'year': year,
        'examType': examType,
        'isOX': isOX,
      };
  // 중앙 파싱 메서드
  static Quiz _fromMap(Map<String, dynamic> map, {Logger? logger}) {
    String? imageUrl = map['imageUrl'];
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl =
          'https://firebasestorage.googleapis.com/v0/b/nursingquizapp6.appspot.com/o/$imageUrl?alt=media';
    }
    logger?.d('이미지 URL 처리 완료: $imageUrl');

    return Quiz(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctOptionIndex: map['correctOptionIndex'] ?? 0,
      explanation: map['explanation'] ?? '',
      typeId: map['typeId'] ?? '',
      keywords: (map['keywords'] as List<dynamic>?)
              ?.map((k) => Keyword.fromMap(k as Map<String, dynamic>))
              .toList() ??
          [],
      imageUrl: imageUrl,
      year: map['year'],
      examType: map['examType'],
      isOX: map['isOX'] ?? false,
    );
  }

  factory Quiz.fromFirestore(DocumentSnapshot doc, Logger logger) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id; // Firestore의 문서 ID를 map에 추가
    logger.d('firestore 데이터로 퀴즈 생성: $data');
    return _fromMap(data, logger: logger);
  }

  factory Quiz.fromJson(Map<String, dynamic> json) => _fromMap(json);

  factory Quiz.fromMap(Map<String, dynamic> map) => _fromMap(map);

  Map<String, dynamic> toJson() => _toMap();

  Map<String, dynamic> toFirestore() {
    _logger.d('퀴즈 데이터를 Firestore에 변환');
    return _toMap();
  }

  // copyWith 메서드 추가
  Quiz copyWith({
    String? id,
    String? question,
    List<String>? options,
    int? correctOptionIndex,
    String? explanation,
    String? typeId,
    List<Keyword>? keywords,
    String? imageUrl,
    int? year,
    String? examType,
    bool? isOX,
  }) {
    return Quiz(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      explanation: explanation ?? this.explanation,
      typeId: typeId ?? this.typeId,
      keywords: keywords ?? this.keywords,
      imageUrl: imageUrl ?? this.imageUrl,
      year: year ?? this.year,
      examType: examType ?? this.examType,
      isOX: isOX ?? this.isOX,
    );
  }
}
