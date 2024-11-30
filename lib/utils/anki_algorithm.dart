import 'dart:math' as math;
import 'package:logger/logger.dart';

class AnkiAlgorithm {
  static const int initialInterval = 10; // 10분
  static final Logger _logger = Logger();

  // Modified: Make _targetRetention configurable
  static double _targetRetention = 0.8; // Default target retention

  // Add getter and setter for targetRetention
  static double get targetRetention => _targetRetention;
  static set targetRetention(double value) {
    _targetRetention =
        value.clamp(0.7, 0.95); // Limit range between 70% and 95%
  }

  // FSRS 파라미터
  static const double _minStability = 1.0; // 최소 안정도
  static const double _minDifficulty = 0.1; // 최소 난이도
  static const double _maxDifficulty = 1.0; // 최대 난이도

  // 최대 복습 간격을 15일(21600분)로 제한하는 상수 추가 (기존 45일의 1/3)
  static const int maxInterval = 21600; // 15일

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
    double currentStability = interval.toDouble();
    double currentDifficulty =
        _convertEaseFactorToDifficulty(easeFactor ?? 2.5);

    _logger.i(
        'FSRS 계산 시작: stability=$currentStability, difficulty=$currentDifficulty');

    // 응답 품질 계산 (1-5)
    int responseQuality = qualityOfRecall ?? (isCorrect ? 4 : 1);

    // 난이도 업데이트
    double newDifficulty = _updateDifficulty(currentDifficulty, responseQuality,
        isUnderstandingImproved, consecutiveCorrect);

    // 안정도 업데이트
    double newStability = _updateStability(currentStability, isCorrect,
        newDifficulty, consecutiveCorrect, isUnderstandingImproved);

    // 다음 복습 간격 계산 (1/3로 감소)
    int newInterval = (_calculateNextInterval(newStability) / 3).round();

    _logger.d('''FSRS 계산 결과:
      난이도: $currentDifficulty → $newDifficulty
      안정도: $currentStability → $newStability
      간격: $interval → $newInterval''');

    return {
      'interval': newInterval,
      'easeFactor': _convertDifficultyToEaseFactor(newDifficulty),
      'consecutiveCorrect': isCorrect ? consecutiveCorrect + 1 : 0,
      'mistakeCount': _updateMistakeCount(
          mistakeCount ?? 0, isCorrect, isUnderstandingImproved),
    };
  }

  static double _updateDifficulty(
    double currentDifficulty,
    int responseQuality,
    bool isUnderstandingImproved,
    int consecutiveCorrect,
  ) {
    double delta = 0.1 * (responseQuality - 3);

    // 연속 정답에 따른 난이도 감소
    if (consecutiveCorrect > 0) {
      delta -= 0.02 * consecutiveCorrect;
    }

    // 이해도 향상에 따른 추가 난이도 감소
    if (isUnderstandingImproved) {
      delta -= 0.05;
    }

    return math.max(
        _minDifficulty, math.min(_maxDifficulty, currentDifficulty - delta));
  }

  static double _updateStability(
    double currentStability,
    bool isCorrect,
    double difficulty,
    int consecutiveCorrect,
    bool isUnderstandingImproved,
  ) {
    if (!isCorrect) {
      return math.max(_minStability, currentStability * 0.5);
    }

    double stabilityIncrease = 1.0 + (1.0 - difficulty);

    // 연속 정답 보너스
    stabilityIncrease *= (1.0 + consecutiveCorrect * 0.1);

    // 이해도 향상 보너스
    if (isUnderstandingImproved) {
      stabilityIncrease *= 1.2;
    }

    return currentStability * stabilityIncrease;
  }

  static int _calculateNextInterval(double stability) {
    // Calculate interval using the current target retention
    int interval = (stability * (-math.log(_targetRetention))).round();
    // 최소값과 최대값 사이로 제한
    return math.max(initialInterval, math.min(maxInterval, interval));
  }

  static int _updateMistakeCount(
    int currentMistakes,
    bool isCorrect,
    bool isUnderstandingImproved,
  ) {
    if (!isCorrect) {
      return currentMistakes + (isUnderstandingImproved ? 0 : 1);
    }
    return math.max(0, currentMistakes - 1);
  }

  // 기존 ease factor와의 호환성을 위한 변환 메서드
  static double _convertEaseFactorToDifficulty(double easeFactor) {
    return math.max(_minDifficulty, math.min(_maxDifficulty, 2.5 - easeFactor));
  }

  static double _convertDifficultyToEaseFactor(double difficulty) {
    return math.max(1.3, math.min(2.5, 2.5 - difficulty));
  }

  // 기존 메서드 유지 (호환성)
  static DateTime calculateNextReviewDate(int interval, double multiplier) {
    return DateTime.now()
        .add(Duration(minutes: (interval * multiplier).round()));
  }

  static int evaluateRecallQuality(Duration answerTime, bool isCorrect) {
    if (!isCorrect) return 1;

    final seconds = answerTime.inSeconds;
    if (seconds < 3) return 5;
    if (seconds < 10) return 4;
    if (seconds < 20) return 3;
    return 2;
  }

  static double calculateIntervalForRetention(double days, double retention) {
    // Calculate interval using the current target retention
    return days * (-math.log(retention));
  }
}
