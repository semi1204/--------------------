import 'package:cloud_firestore/cloud_firestore.dart';

class Subject {
  final String id;
  final String name;

  Subject({required this.id, required this.name});

  factory Subject.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Subject(
      id: doc.id,
      name: data['name'] ?? '',
    );
  }

  // 수정: JSON 직렬화를 위한 메서드 추가
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  // 수정: fromJson 메서드 추가
  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }

  // 기존 메서드는 그대로 유지
  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'name': name,
      };
}
