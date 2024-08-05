import 'dart:math';
import 'package:logger/logger.dart';

Logger _logger = Logger();

class AnkiAlgorithm {
  static const int _initialInterval = 1; // 초기 간격을 1일로 설정
  static const double _defaultEaseFactor = 2.5; // 기본 용이성 계수를 2.5로 설정
  static const double _minEaseFactor = 1.3; // 최소 용이성 계수를 1.3으로 설정

  static const bool _isDevelopmentMode = true;

  // 수정: calculateNextReview 메서드 업데이트
  static Map<String, dynamic> calculateNextReview({
    required int interval,
    double? easeFactor,
    required int consecutiveCorrect,
    required bool isCorrect,
    int? qualityOfRecall,
    int? mistakeCount,
  }) {
    easeFactor ??= _defaultEaseFactor; // 용이성 계수가 주어지지 않으면 기본값 사용

    _logger.i(
        'Calculating next review: interval=$interval, easeFactor=$easeFactor, consecutiveCorrect=$consecutiveCorrect, isCorrect=$isCorrect, qualityOfRecall=$qualityOfRecall, mistakeCount=$mistakeCount');

    if (!isCorrect) {
      return _handleIncorrectAnswer(interval, easeFactor, mistakeCount);
    }

    Map<String, dynamic> result = _handleCorrectAnswer(interval, easeFactor,
        consecutiveCorrect, qualityOfRecall, mistakeCount);

    _logger.i(
        'calculateNextReview 결과: interval=${result['interval']}, nextReviewDate=${DateTime.now().add(Duration(days: result['interval'] as int))}');

    return result;
  }

  // 새로운 메서드: 오답 처리
  static Map<String, dynamic> _handleIncorrectAnswer(
      int interval, double easeFactor, int? mistakeCount) {
    _logger.d('Handling incorrect answer');
    // Decrease the ease factor more aggressively for repeated mistakes
    double newEaseFactor =
        max(_minEaseFactor, easeFactor - (0.2 * (mistakeCount ?? 1)));
    // Reduce the interval more for repeated mistakes
    int newInterval = _isDevelopmentMode
        ? max(1, (interval ~/ (1 + (mistakeCount ?? 0) * 0.1)).toInt())
        : max(
            1,
            (interval ~/ 2)
                .toInt()); // Original: max(1, (interval ~/ 2).toInt());
    return {
      'interval': newInterval, // 새로운 간격
      'easeFactor': newEaseFactor, // 새로운 용이성 계수
      'consecutiveCorrect': 0, // 연속 정답 횟수 초기화
      'mistakeCount': (mistakeCount ?? 0) + 1, // 실수 횟수 증가
    };
  }

  // 정답처리 메서드
  static Map<String, dynamic> _handleCorrectAnswer(
      int interval,
      double easeFactor,
      int consecutiveCorrect,
      int? qualityOfRecall,
      int? mistakeCount) {
    _logger.d('Handling correct answer');
    int newInterval;
    double newEaseFactor = easeFactor;

    if (consecutiveCorrect == 0) {
      newInterval = _isDevelopmentMode
          ? 1
          : _initialInterval; // Original: _initialInterval;
    } else if (consecutiveCorrect == 1) {
      newInterval = _isDevelopmentMode ? 3 : 6; // Original: 6;
    } else {
      newInterval = _calculateNewInterval(interval, easeFactor, qualityOfRecall,
          mistakeCount, consecutiveCorrect);
      newEaseFactor =
          _calculateNewEaseFactor(easeFactor, qualityOfRecall, mistakeCount);
    }

    return {
      'interval': newInterval, // 새로운 간격
      'easeFactor': newEaseFactor, // 새로운 용이성 계수
      'consecutiveCorrect': consecutiveCorrect + 1,
      'mistakeCount': max(
          0, // 연속 정답 횟수 증가
          (mistakeCount ?? 0) - 1), // 정답일 경우 실수 횟수 감소
    };
  }

  // to calculate new interval
  static int _calculateNewInterval(int interval, double easeFactor,
      int? qualityOfRecall, int? mistakeCount, int consecutiveCorrect) {
    _logger.d('Calculating new interval');
    double multiplier = easeFactor;
    if (qualityOfRecall != null) {
      multiplier *= (0.5 + qualityOfRecall / 5);
    }
    if (consecutiveCorrect > 3) {
      multiplier *= 1 + (consecutiveCorrect - 3) * 0.1;
    }

    int adjustedInterval = (interval * multiplier).round();

    if (_isDevelopmentMode) {
      return max(1, adjustedInterval - (mistakeCount ?? 0));
    } else {
      return max(1, adjustedInterval - (mistakeCount ?? 0));
    }
  }

  // method to calculate new ease factor
  static double _calculateNewEaseFactor(
      double easeFactor, int? qualityOfRecall, int? mistakeCount) {
    _logger.d('Calculating new ease factor');
    if (qualityOfRecall == null) return easeFactor;

    // More aggressive ease factor adjustment
    double change =
        0.15 - (5 - qualityOfRecall) * (0.1 + (5 - qualityOfRecall) * 0.02);
    double adjustedEaseFactor =
        max(_minEaseFactor, easeFactor + change - (mistakeCount ?? 0) * 0.05);
    return adjustedEaseFactor;
  }

  // method to evaluate recall quality
  static int evaluateRecallQuality(Duration answerTime, bool isCorrect) {
    _logger.d(
        'Evaluating recall quality: answerTime=$answerTime, isCorrect=$isCorrect');

    if (!isCorrect) return 0;

    // Use the same minute-based logic for both development and production
    if (answerTime.inSeconds < 60) return 5; // 1분 미만 : 기억의 질 5
    if (answerTime.inSeconds < 180) return 4; // 1분 이상 3분 미만 : 기억의 질 4
    if (answerTime.inSeconds < 600) return 3; // 3분 이상 10분 미만 : 기억의 질 3
    return 2; // More than 10 minutes
  }
}
