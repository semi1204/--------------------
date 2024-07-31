import 'dart:math';
import 'package:logger/logger.dart';

Logger _logger = Logger();

class AnkiAlgorithm {
  static const int _initialInterval = 1;
  static const double _defaultEaseFactor = 2.5;
  static const double _minEaseFactor = 1.3;

  // 수정: calculateNextReview 메서드 업데이트
  static Map<String, dynamic> calculateNextReview({
    required int interval,
    double? easeFactor,
    required int consecutiveCorrect,
    required bool isCorrect,
    int? qualityOfRecall,
  }) {
    // 수정: easeFactor가 null이면 _defaultEaseFactor 사용
    easeFactor ??= _defaultEaseFactor;

    _logger.i(
        'Calculating next review: interval=$interval, easeFactor=$easeFactor, consecutiveCorrect=$consecutiveCorrect, isCorrect=$isCorrect, qualityOfRecall=$qualityOfRecall');

    if (!isCorrect) {
      return _handleIncorrectAnswer(interval, easeFactor);
    }

    return _handleCorrectAnswer(
        interval, easeFactor, consecutiveCorrect, qualityOfRecall);
  }

  // 새로운 메서드: 오답 처리
  static Map<String, dynamic> _handleIncorrectAnswer(
      int interval, double easeFactor) {
    _logger.d('Handling incorrect answer');
    return {
      'interval': _initialInterval,
      'easeFactor': max(_minEaseFactor, easeFactor - 0.2),
      'consecutiveCorrect': 0,
    };
  }

  // 새로운 메서드: 정답 처리
  static Map<String, dynamic> _handleCorrectAnswer(int interval,
      double easeFactor, int consecutiveCorrect, int? qualityOfRecall) {
    _logger.d('Handling correct answer');
    int newInterval;
    double newEaseFactor = easeFactor;

    if (consecutiveCorrect == 0) {
      newInterval = _initialInterval;
    } else if (consecutiveCorrect == 1) {
      newInterval = 6;
    } else {
      newInterval =
          _calculateNewInterval(interval, easeFactor, qualityOfRecall);
      newEaseFactor = _calculateNewEaseFactor(easeFactor, qualityOfRecall);
    }

    return {
      'interval': newInterval,
      'easeFactor': newEaseFactor,
      'consecutiveCorrect': consecutiveCorrect + 1,
    };
  }

  // 새로운 메서드: 새 간격 계산
  static int _calculateNewInterval(
      int interval, double easeFactor, int? qualityOfRecall) {
    _logger.d('Calculating new interval');
    double multiplier = easeFactor;
    if (qualityOfRecall != null) {
      multiplier *=
          (0.5 + qualityOfRecall / 5); // Adjust based on quality of recall
    }
    return (interval * multiplier).round();
  }

  // 새로운 메서드: 새 난이도 요소 계산
  static double _calculateNewEaseFactor(
      double easeFactor, int? qualityOfRecall) {
    _logger.d('Calculating new ease factor');
    if (qualityOfRecall == null) return easeFactor;

    double change =
        0.1 - (5 - qualityOfRecall) * (0.08 + (5 - qualityOfRecall) * 0.02);
    return max(_minEaseFactor, easeFactor + change);
  }

  // 새로운 메서드: 복습 품질 평가
  static int evaluateRecallQuality(Duration answerTime, bool isCorrect) {
    _logger.d(
        'Evaluating recall quality: answerTime=$answerTime, isCorrect=$isCorrect');
    if (!isCorrect) return 0;
    if (answerTime.inSeconds < 3) return 5;
    if (answerTime.inSeconds < 10) return 4;
    if (answerTime.inSeconds < 20) return 3;
    return 2;
  }
}
