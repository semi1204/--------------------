import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final AnalyticsService _instance = AnalyticsService._internal();

  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  Future<void> logQuizCompleted({
    required String quizId,
    required String subjectId,
    required bool isCorrect,
    required int timeSpent,
    String? userId,
  }) async {
    final Map<String, Object> params = {
      'quiz_id': quizId,
      'subject_id': subjectId,
      'is_correct': isCorrect,
      'time_spent': timeSpent,
    };

    if (userId != null) {
      params['user_id'] = userId;
    }

    await _analytics.logEvent(
      name: 'quiz_completed',
      parameters: params,
    );
  }

  Future<void> logUserAction({
    required String action,
    required Map<String, dynamic> parameters,
  }) async {
    final Map<String, Object> params = Map<String, Object>.from(parameters);

    await _analytics.logEvent(
      name: action,
      parameters: params,
    );
  }
}
