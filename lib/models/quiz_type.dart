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

  factory QuizType.fromMap(Map<String, dynamic> map) {
    return QuizType(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      subjectId: map['subjectId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'subjectId': subjectId,
      };
}
