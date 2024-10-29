import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/keyword.dart';

class KeywordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();

  Future<List<Keyword>> getAllKeywords() async {
    try {
      final snapshot = await _firestore.collection('keywords').get();
      return snapshot.docs.map((doc) => Keyword.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error fetching all keywords: $e');
      rethrow;
    }
  }

  Future<Keyword> getKeywordById(String id) async {
    try {
      final doc = await _firestore.collection('keywords').doc(id).get();
      if (doc.exists) {
        return Keyword.fromFirestore(doc);
      } else {
        throw Exception('Keyword not found');
      }
    } catch (e) {
      _logger.e('Error fetching keyword by id: $e');
      rethrow;
    }
  }

  Future<Keyword> addKeyword(String content) async {
    try {
      final docRef = await _firestore.collection('keywords').add({
        'content': content,
        'linkedQuizIds': [],
      });
      return Keyword(id: docRef.id, content: content);
    } catch (e) {
      _logger.e('Error adding keyword: $e');
      rethrow;
    }
  }

  Future<void> updateKeyword(Keyword keyword) async {
    try {
      await _firestore
          .collection('keywords')
          .doc(keyword.id)
          .update(keyword.toMap());
    } catch (e) {
      _logger.e('Error updating keyword: $e');
      rethrow;
    }
  }

  Future<void> deleteKeyword(String id) async {
    try {
      await _firestore.collection('keywords').doc(id).delete();
    } catch (e) {
      _logger.e('Error deleting keyword: $e');
      rethrow;
    }
  }

  Future<void> linkKeywordToQuiz(String keywordId, String quizId) async {
    try {
      await _firestore.collection('keywords').doc(keywordId).update({
        'linkedQuizIds': FieldValue.arrayUnion([quizId])
      });
    } catch (e) {
      _logger.e('Error linking keyword to quiz: $e');
      rethrow;
    }
  }

  Future<void> unlinkKeywordFromQuiz(String keywordId, String quizId) async {
    try {
      await _firestore.collection('keywords').doc(keywordId).update({
        'linkedQuizIds': FieldValue.arrayRemove([quizId])
      });
    } catch (e) {
      _logger.e('Error unlinking keyword from quiz: $e');
      rethrow;
    }
  }

  Future<List<Keyword>> getKeywordsForQuiz(String quizId) async {
    try {
      final snapshot = await _firestore
          .collection('keywords')
          .where('linkedQuizIds', arrayContains: quizId)
          .get();
      return snapshot.docs.map((doc) => Keyword.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error fetching keywords for quiz: $e');
      rethrow;
    }
  }

  Future<Keyword?> findKeywordByContent(String content) async {
    try {
      final snapshot = await _firestore
          .collection('keywords')
          .where('content', isEqualTo: content)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Keyword.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      _logger.e('Error finding keyword by content: $e');
      rethrow;
    }
  }

  // 새로운 메서드 추가
  Future<List<Keyword>> processQuizKeywords(
      List<Keyword> keywords, String quizId) async {
    try {
      List<Keyword> processedKeywords = [];

      for (var keyword in keywords) {
        if (keyword.id.isEmpty) {
          // 기존 키워드 검색
          final existingKeyword = await findKeywordByContent(keyword.content);
          if (existingKeyword != null) {
            await linkKeywordToQuiz(existingKeyword.id, quizId);
            processedKeywords.add(existingKeyword);
          } else {
            // 새 키워드 추가
            final newKeyword = await addKeyword(keyword.content);
            await linkKeywordToQuiz(newKeyword.id, quizId);
            processedKeywords.add(newKeyword);
          }
        } else {
          await linkKeywordToQuiz(keyword.id, quizId);
          processedKeywords.add(keyword);
        }
      }

      return processedKeywords;
    } catch (e) {
      _logger.e('Error processing quiz keywords: $e');
      rethrow;
    }
  }

  Future<void> removeQuizKeywords(String quizId) async {
    try {
      final keywords = await getKeywordsForQuiz(quizId);
      for (var keyword in keywords) {
        await unlinkKeywordFromQuiz(keyword.id, quizId);
      }
    } catch (e) {
      _logger.e('Error removing quiz keywords: $e');
      rethrow;
    }
  }
}
