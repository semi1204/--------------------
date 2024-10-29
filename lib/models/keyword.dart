import 'package:cloud_firestore/cloud_firestore.dart';

class Keyword {
  final String id;
  final String content;
  final List<String> linkedQuizIds;
  final String? description; // 키워드에 대한 설명 추가

  Keyword({
    required this.id,
    required this.content,
    this.linkedQuizIds = const [],
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'linkedQuizIds': linkedQuizIds,
      'description': description,
    };
  }

  factory Keyword.fromMap(Map<String, dynamic> map) {
    return Keyword(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      linkedQuizIds: List<String>.from(map['linkedQuizIds'] ?? []),
      description: map['description'],
    );
  }

  factory Keyword.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Keyword(
      id: doc.id,
      content: data['content'] ?? '',
      linkedQuizIds: List<String>.from(data['linkedQuizIds'] ?? []),
      description: data['description'],
    );
  }

  Keyword copyWith({
    String? id,
    String? content,
    List<String>? linkedQuizIds,
    String? description,
  }) {
    return Keyword(
      id: id ?? this.id,
      content: content ?? this.content,
      linkedQuizIds: linkedQuizIds ?? this.linkedQuizIds,
      description: description ?? this.description,
    );
  }
}
