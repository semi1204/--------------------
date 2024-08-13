import 'package:cloud_firestore/cloud_firestore.dart';

class QuizType {
  final String id;
  final String name;
  final String subjectId;

  QuizType({required this.id, required this.name, required this.subjectId});

  // 중앙 변환 메서드
  Map<String, dynamic> _toMap() => {
        'id': id,
        'name': name,
        'subjectId': subjectId,
      };

  // 중앙 파싱 메서드
  static QuizType _fromMap(Map<String, dynamic> map) {
    return QuizType(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      subjectId: map['subjectId'] ?? '',
    );
  }

  factory QuizType.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id; // Firestore의 문서 ID를 map에 추가
    return _fromMap(data);
  }

  factory QuizType.fromJson(Map<String, dynamic> json) => _fromMap(json);

  factory QuizType.fromMap(Map<String, dynamic> map) => _fromMap(map);

  Map<String, dynamic> toJson() => _toMap();

  Map<String, dynamic> toFirestore() => _toMap();
}
