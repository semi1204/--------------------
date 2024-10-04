// anki_algorithm.dart
import 'dart:math';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

final _logger = Logger(
  printer: PrettyPrinter(),
  level:
      kDebugMode ? Level.debug : Level.error, // Adjust log level based on build
);

class AnkiAlgorithm {
  static const int initialInterval =
      kDebugMode ? 1 : 1440; // 디버그 모드: 1분, 실제 모드: 1일(1440분)
  static const double defaultEaseFactor = 2.5; // 기본 용이성 계수
  static const double _minEaseFactor = 1.3; // 최소 용이성 계수

  static Map<String, dynamic> calculateNextReview({
    required int interval,
    double? easeFactor,
    required int consecutiveCorrect,
    required bool isCorrect,
    int? qualityOfRecall,
    int? mistakeCount,
    bool isUnderstandingImproved = false,
    required bool markForReview,
    double? reviewPeriodMultiplier, // 사용자가 설정한 복습주기 계수 (기본값: 1.0)
  }) {
    easeFactor ??= defaultEaseFactor;
    reviewPeriodMultiplier ??= 1.0; // 기본값 설정
    _logger.i('복습 계산 시작: interval=$interval, easeFactor=$easeFactor, ...');

    if (isUnderstandingImproved) {
      return _handleImprovedUnderstanding(
          interval, easeFactor, consecutiveCorrect, mistakeCount);
    }

    return isCorrect
        ? _handleCorrectAnswer(interval, easeFactor, consecutiveCorrect,
            qualityOfRecall, mistakeCount, isUnderstandingImproved)
        : _handleIncorrectAnswer(interval, easeFactor, consecutiveCorrect,
            mistakeCount, isUnderstandingImproved);
  }

  static Map<String, dynamic> _handleImprovedUnderstanding(int interval,
      double easeFactor, int consecutiveCorrect, int? mistakeCount) {
    _logger.d('이해도 향상 처리 중');

    // 이해도 향상 시 간격 증가를 더 크게 조정
    int newInterval = (interval * 2.0).round(); // 1.5에서 2.0으로 증가
    // 이해도 향상 시 용이성 계수 증가를 더 크게 조정
    double newEaseFactor = min(easeFactor + 0.25, 2.5); // 0.15에서 0.25로 증가

    return {
      'interval': newInterval,
      'easeFactor': newEaseFactor,
      'consecutiveCorrect': consecutiveCorrect + 1,
      'mistakeCount': max(0, (mistakeCount ?? 0) - 1),
    };
  }

  static Map<String, dynamic> _handleIncorrectAnswer(
      int interval,
      double easeFactor,
      int consecutiveCorrect,
      int? mistakeCount,
      bool isUnderstandingImproved) {
    _logger.d('오답 처리 중');

    int newInterval = _calculateNewInterval(
        interval, isUnderstandingImproved, mistakeCount, consecutiveCorrect,
        isCorrect: false);

    double newEaseFactor = max(
        _minEaseFactor,
        easeFactor -
            (isUnderstandingImproved ? 0.05 : 0.2) *
                (mistakeCount ?? 1)); // 0.1에서 0.05로 감소

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
        interval, isUnderstandingImproved, mistakeCount, consecutiveCorrect,
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

  static int _calculateNewInterval(int interval, bool isUnderstandingImproved,
      int? mistakeCount, int consecutiveCorrect,
      {bool isCorrect = false}) {
    // 이해도 향상 시 간격 증가를 더 크게 조정
    double multiplier;

    if (isCorrect) {
      if (isUnderstandingImproved) {
        // Understanding improved intervals: 1d, 4d, 9d, 20d
        if (consecutiveCorrect == 0) {
          multiplier = 1.0; // Initial interval
        } else if (consecutiveCorrect == 1) {
          multiplier = 4.0; // From 1d to 4d
        } else if (consecutiveCorrect == 2) {
          multiplier = 2.25; // From 4d to 9d
        } else if (consecutiveCorrect == 3) {
          multiplier = 2.22; // From 9d to 20d
        } else {
          multiplier = 2.0; // Subsequent reviews
        }
      } else {
        // Understanding not improved intervals: 1d, 2d, 3d
        if (consecutiveCorrect == 0) {
          multiplier = 1.0; // Initial interval
        } else if (consecutiveCorrect == 1) {
          multiplier = 2.0; // From 1d to 2d
        } else if (consecutiveCorrect == 2) {
          multiplier = 1.5; // From 2d to 3d
        } else {
          multiplier = 1.5; // Subsequent reviews
        }
      }
    } else {
      // Incorrect answers
      multiplier = isUnderstandingImproved ? 0.8 : 0.5;
    }

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

    // 이해도 향상 시 용이성 계수 변화를 더 크게 조정
    double change = 0.15 * (qualityOfRecall - 3); // 0.1에서 0.15로 증가

    change *= isUnderstandingImproved ? 1.2 : 0.9; // 1.1에서 1.2로 증가

    return max(
        _minEaseFactor,
        easeFactor +
            change -
            (mistakeCount ?? 0) * 0.05 +
            (isUnderstandingImproved ? 0.1 : 0)); // 0.05에서 0.1로 증가
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

  // 다음 복습 날짜를 계산하는 메소드입니다. 주어진 간격에 따라 다음 복습 날짜를 반환합니다.
  static DateTime calculateNextReviewDate(
      int interval, double reviewPeriodMultiplier) {
    // 로그를 통해 현재 간격을 기록합니다.
    _logger.d(
        '다음 복습 날짜 계산: interval=$interval, reviewPeriodMultiplier=$reviewPeriodMultiplier');
    // 마지막 복습 날짜에 주어진 간격(분)을 더하여 다음 복습 날짜를 계산합니다.
    return DateTime.now()
        .add(Duration(minutes: (interval * reviewPeriodMultiplier).round()));
  }
}
