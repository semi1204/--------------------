import 'dart:math';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

final _logger = Logger();

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
  }) {
    easeFactor ??= defaultEaseFactor;
    _logger.i('복습 계산 시작: interval=$interval, easeFactor=$easeFactor, ...');

    // TODO ; MarkForReview로직을 고쳐야함
    // 수정방향: 복습버튼을 누르면 anki 알고리즘을 사용하는 로직으로 변경해야함. 항상 초기화 된 값을 반환하는 게 아님.
    if (markForReview) {
      return _handleMarkForReview(
          interval, easeFactor, consecutiveCorrect, mistakeCount);
    }

    // 피드백 처리 로직 추가
    if (isUnderstandingImproved) {
      return _handleImprovedUnderstanding(
          interval, easeFactor, consecutiveCorrect, mistakeCount);
    }

    return isCorrect
        ? _handleCorrectAnswer(interval, easeFactor, consecutiveCorrect,
            qualityOfRecall, mistakeCount, isUnderstandingImproved)
        : _handleIncorrectAnswer(
            interval, easeFactor, mistakeCount, isUnderstandingImproved);
  }

  static Map<String, dynamic> _handleMarkForReview(int interval,
      double easeFactor, int consecutiveCorrect, int? mistakeCount) {
    _logger.d('복습 표시 처리 중');

    // Apply a modified Anki algorithm for review marking
    int newInterval = max(initialInterval, (interval * 0.5).round());
    double newEaseFactor = max(_minEaseFactor, easeFactor - 0.15);

    return {
      'interval': newInterval,
      'easeFactor': newEaseFactor,
      'consecutiveCorrect': max(0, consecutiveCorrect - 1),
      'mistakeCount': (mistakeCount ?? 0) + 1,
    };
  }

  static Map<String, dynamic> _handleImprovedUnderstanding(int interval,
      double easeFactor, int consecutiveCorrect, int? mistakeCount) {
    _logger.d('이해도 향상 처리 중');

    int newInterval = (interval * 1.5).round();
    double newEaseFactor = min(easeFactor + 0.15, 2.5);

    return {
      'interval': newInterval,
      'easeFactor': newEaseFactor,
      'consecutiveCorrect': consecutiveCorrect + 1,
      'mistakeCount': max(0, (mistakeCount ?? 0) - 1),
    };
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

  // 다음 복습 날짜를 계산하는 메소드입니다. 주어진 간격에 따라 다음 복습 날짜를 반환합니다.
  static DateTime calculateNextReviewDate(int interval) {
    // 로그를 통해 현재 간격을 기록합니다.
    _logger.d('다음 복습 날짜 계산: interval=$interval');
    // 현재 시간에 주어진 간격(분)을 더하여 다음 복습 날짜를 계산합니다.
    return DateTime.now().add(Duration(minutes: interval));
  }
}
