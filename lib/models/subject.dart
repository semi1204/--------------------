import 'package:cloud_firestore/cloud_firestore.dart';

class Subject {
  final String id;
  final String name;

  Subject({required this.id, required this.name});

  // 중앙 변환 메서드
  Map<String, dynamic> _toMap() => {
        'id': id,
        'name': name,
      };

  // 중앙 파싱 메서드
  static Subject _fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
    );
  }

  factory Subject.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id; // Firestore의 문서 ID를 map에 추가
    return _fromMap(data);
  }

  factory Subject.fromJson(Map<String, dynamic> json) => _fromMap(json);

  factory Subject.fromMap(Map<String, dynamic> map) => _fromMap(map);

  Map<String, dynamic> toJson() => _toMap();

  Map<String, dynamic> toFirestore() => _toMap();
}
