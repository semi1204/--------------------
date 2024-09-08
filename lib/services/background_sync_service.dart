import 'dart:async';
import 'package:nursing_quiz_app_6/services/quiz_service.dart';

class BackgroundSyncService {
  final QuizService _quizService;

  BackgroundSyncService(this._quizService);

  Future<void> syncAllData() async {
    try {
      final subjects = await _quizService.getSubjects(forceRefresh: true);
      for (final subject in subjects) {
        final quizTypes =
            await _quizService.getQuizTypes(subject.id, forceRefresh: true);
        for (final quizType in quizTypes) {
          await _quizService.getQuizzes(subject.id, quizType.id,
              forceRefresh: true);
        }
      }
    } catch (e) {
      print('Background sync failed: $e');
      rethrow;
    }
  }
}
