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

  // Add this method for caching
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
