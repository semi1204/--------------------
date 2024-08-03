import 'package:cloud_firestore/cloud_firestore.dart';

class QuizType {
  final String id;
  final String name;
  final String subjectId;

  QuizType({required this.id, required this.name, required this.subjectId});

  factory QuizType.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return QuizType(
      id: doc.id,
      name: data['name'] ?? '',
      subjectId: data['subjectId'] ?? '',
    );
  }

  //fromJson 메서드
  factory QuizType.fromJson(Map<String, dynamic> json) {
    return QuizType(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      subjectId: json['subjectId'] ?? '',
    );
  }

  // 기존 메서드 유지
  factory QuizType.fromMap(Map<String, dynamic> map) {
    return QuizType(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      subjectId: map['subjectId'] ?? '',
    );
  }

  // toJson 메서드 추가
  Map<String, dynamic> toJson() => toFirestore();

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'name': name,
        'subjectId': subjectId,
      };
}
