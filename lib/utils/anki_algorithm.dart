import 'dart:math';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

Logger _logger = Logger();

class AnkiAlgorithm {
  static const int initialInterval =
      kDebugMode ? 1 : 1440; // 디버그 모드: 1분, 실제 모드: 1일(1440분)
  static const double defaultEaseFactor = 2.5;
  static const double _minEaseFactor = 1.3;

  static Map<String, dynamic> calculateNextReview({
    required int interval,
    double? easeFactor,
    required int consecutiveCorrect,
    required bool isCorrect,
    int? qualityOfRecall,
    int? mistakeCount,
    bool isUnderstandingImproved = false,
    required bool markForReview,
  }) {
    easeFactor ??= defaultEaseFactor;
    _logger.i('복습 계산 시작: interval=$interval, easeFactor=$easeFactor, ...');

    if (markForReview) {
      return {
        'interval': initialInterval,
        'easeFactor': easeFactor,
        'consecutiveCorrect': 0,
        'mistakeCount': 0,
      };
    }

    return isCorrect
        ? _handleCorrectAnswer(interval, easeFactor, consecutiveCorrect,
            qualityOfRecall, mistakeCount, isUnderstandingImproved)
        : _handleIncorrectAnswer(
            interval, easeFactor, mistakeCount, isUnderstandingImproved);
  }

  static Map<String, dynamic> _handleIncorrectAnswer(int interval,
      double easeFactor, int? mistakeCount, bool isUnderstandingImproved) {
    _logger.d('오답 처리 중');

    double newEaseFactor = max(
        _minEaseFactor,
        easeFactor -
            (isUnderstandingImproved ? 0.1 : 0.2) * (mistakeCount ?? 1));

    int newInterval =
        _calculateNewInterval(interval, isUnderstandingImproved, mistakeCount);

    return {
      'interval': newInterval,
      'easeFactor': newEaseFactor,
      'consecutiveCorrect': 0,
      'mistakeCount': (mistakeCount ?? 0) + (isUnderstandingImproved ? 0 : 1),
    };
  }

  static Map<String, dynamic> _handleCorrectAnswer(
      int interval,
      double easeFactor,
      int consecutiveCorrect,
      int? qualityOfRecall,
      int? mistakeCount,
      bool isUnderstandingImproved) {
    _logger.d('정답 처리 중');

    int newInterval = _calculateNewInterval(
        interval, isUnderstandingImproved, mistakeCount,
        isCorrect: true);
    double newEaseFactor = _calculateNewEaseFactor(
        easeFactor, qualityOfRecall, mistakeCount, isUnderstandingImproved);

    return {
      'interval': newInterval,
      'easeFactor': newEaseFactor,
      'consecutiveCorrect': consecutiveCorrect + 1,
      'mistakeCount': max(0, (mistakeCount ?? 0) - 1),
    };
  }

  static int _calculateNewInterval(
      int interval, bool isUnderstandingImproved, int? mistakeCount,
      {bool isCorrect = false}) {
    double multiplier = isCorrect
        ? (isUnderstandingImproved ? 2.5 : 2.0)
        : (isUnderstandingImproved ? 0.7 : 0.5);

    int newInterval = (interval * multiplier).round();

    // 실수 횟수에 따른 조정
    if (mistakeCount != null && mistakeCount > 0) {
      newInterval = (newInterval * (1 - 0.1 * mistakeCount)).round();
    }

    // 최소 간격 보장
    return max(kDebugMode ? 1 : 60, newInterval); // 디버그 모드: 1분, 실제 모드: 1시간
  }

  static double _calculateNewEaseFactor(double easeFactor, int? qualityOfRecall,
      int? mistakeCount, bool isUnderstandingImproved) {
    _logger.d('새로운 용이성 계수 계산 시작');

    if (qualityOfRecall == null) return easeFactor;

    double change = 0.1 * (qualityOfRecall - 3);

    change *= isUnderstandingImproved ? 1.1 : 0.9;

    return max(
        _minEaseFactor,
        easeFactor +
            change -
            (mistakeCount ?? 0) * 0.05 +
            (isUnderstandingImproved ? 0.05 : 0));
  }

  static int evaluateRecallQuality(Duration answerTime, bool isCorrect) {
    _logger.d('회상 품질 평가: answerTime=$answerTime, isCorrect=$isCorrect');

    if (!isCorrect) return 0;

    if (kDebugMode) {
      if (answerTime.inSeconds < 10) return 5;
      if (answerTime.inSeconds < 20) return 4;
      if (answerTime.inSeconds < 30) return 3;
      return 2;
    } else {
      if (answerTime.inSeconds < 60) return 5;
      if (answerTime.inSeconds < 180) return 4;
      if (answerTime.inSeconds < 600) return 3;
      return 2;
    }
  }

  static DateTime calculateNextReviewDate(int interval) {
    _logger.d('다음 복습 날짜 계산: interval=$interval');
    return DateTime.now().add(Duration(minutes: interval));
  }
}
