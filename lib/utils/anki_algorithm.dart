import 'dart:math';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

Logger _logger = Logger();

class AnkiAlgorithm {
  static const int initialInterval = 1; // 초기 간격
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
  }) {
    easeFactor ??= defaultEaseFactor;
    _logger.i('복습 계산 시작: interval=$interval, easeFactor=$easeFactor, ...');

    return isCorrect
        ? _handleCorrectAnswer(interval, easeFactor, consecutiveCorrect,
            qualityOfRecall, mistakeCount, isUnderstandingImproved)
        : _handleIncorrectAnswer(
            interval, easeFactor, mistakeCount, isUnderstandingImproved);
  }

  static Map<String, dynamic> _handleIncorrectAnswer(int interval,
      double easeFactor, int? mistakeCount, bool isUnderstandingImproved) {
    _logger.d('오답 처리 중');

    // 새로운 용이성 계수 계산
    // 1. 이해도 향상 여부에 따라 감소폭 결정 (향상: 0.1, 미향상: 0.2)
    // 2. 실수 횟수를 곱해 감소폭 조절
    // 3. 최소값(_minEaseFactor)을 넘지 않도록 함

    double newEaseFactor = max(
        _minEaseFactor,
        easeFactor -
            (isUnderstandingImproved ? 0.1 : 0.2) * (mistakeCount ?? 1));

    // 새로운 복습 간격 계산
    int newInterval;
    if (kDebugMode) {
      // 디버그 모드: 분 단위로 조정
      newInterval = max(
          1,
          (interval *
                  60 ~/
                  (1 +
                      (mistakeCount ?? 0) *
                          (isUnderstandingImproved ? 0.05 : 0.1)))
              .toInt());
    } else {
      // 실제 모드: 현재 간격을 이해도에 따라 1.5 또는 2로 나눔
      newInterval =
          max(1, (interval ~/ (isUnderstandingImproved ? 1.5 : 2)).toInt());
    }

    // 결과 반환
    return {
      'interval': newInterval, // 새로운 복습 간격
      'easeFactor': newEaseFactor, // 새로운 용이성 계수
      'consecutiveCorrect': 0, // 연속 정답 횟수 초기화
      'mistakeCount': (mistakeCount ?? 0) +
          (isUnderstandingImproved ? 0 : 1), // 이해도 미향상 시 실수 횟수 증가
    };
  }

  static Map<String, dynamic> _handleCorrectAnswer(
      int interval,
      double easeFactor,
      int consecutiveCorrect,
      int? qualityOfRecall,
      int? mistakeCount,
      bool isUnderstandingImproved) {
    _logger.d('정답 처리');
    int newInterval;
    double newEaseFactor = easeFactor;

    if (consecutiveCorrect == 0) {
      newInterval = kDebugMode ? 1 : initialInterval; // 디버그 모드: 1분, 릴리즈 모드: 1일
    } else if (consecutiveCorrect == 1) {
      newInterval = kDebugMode ? 5 : 6; // 디버그 모드: 5분, 릴리즈 모드: 6일
    } else {
      // 2회 이상 연속 정답일 경우
      // 새로운 간격 계산
      newInterval = _calculateNewInterval(interval, easeFactor, qualityOfRecall,
          mistakeCount, consecutiveCorrect, isUnderstandingImproved);
      // 새로운 용이성 계수 계산
      newEaseFactor = _calculateNewEaseFactor(
          easeFactor, qualityOfRecall, mistakeCount, isUnderstandingImproved);
    }

    return {
      'interval': newInterval,
      'easeFactor': newEaseFactor,
      'consecutiveCorrect': consecutiveCorrect + 1,
      'mistakeCount':
          max(0, (mistakeCount ?? 0) - (isUnderstandingImproved ? 1 : 0)),
    };
  }

  // _calculateNewInterval 메서드는 개발 모드에 따라 분/일 단위 조정 필요
  static int _calculateNewInterval(
      int interval,
      double easeFactor,
      int? qualityOfRecall,
      int? mistakeCount,
      int consecutiveCorrect,
      bool isUnderstandingImproved) {
    _logger.d('새 간격 계산');

    // 기본 승수 계산: 용이성 계수에 이해도 향상 여부를 반영
    // 이해도가 향상되었다면 10% 증가, 그렇지 않으면 10% 감소
    double multiplier = easeFactor * (isUnderstandingImproved ? 1.1 : 0.9);

    // 회상 품질 반영: 품질이 높을수록 간격이 더 크게 증가
    if (qualityOfRecall != null) {
      multiplier *= (0.5 + qualityOfRecall / 5);
    }

    // 연속 정답 보너스: 3회 이상 연속 정답일 경우 추가 보너스 적용
    // 연속 정답 횟수가 늘어날수록 간격이 더 크게 증가
    if (consecutiveCorrect > 3) {
      multiplier *= 1 + (consecutiveCorrect - 3) * 0.1;
    }

    // 새 간격 계산: 현재 간격에 최종 승수를 곱하여 계산
    int adjustedInterval = (interval * multiplier).round();

    if (kDebugMode) {
      // 디버그 모드: 분 단위로 조정
      // adjustedInterval *= 60; // 이 부분을 제거하거나 주석 처리
    }
    // 실제 모드: 일 단위 (기존 로직 유지)
    // 최종 조정:
    // 1. 실수 횟수를 반영하여 간격 감소
    // 2. 이해도 향상 시 1일 추가
    // 3. 최소 간격은 1일로 유지
    return max(
        kDebugMode ? 1 : initialInterval,
        adjustedInterval -
            (mistakeCount ?? 0) +
            (isUnderstandingImproved ? (kDebugMode ? 60 : 1) : 0));
  }

  static double _calculateNewEaseFactor(double easeFactor, int? qualityOfRecall,
      int? mistakeCount, bool isUnderstandingImproved) {
    _logger.d('새로운 용이성 계수 계산 시작');

    // 회상 품질이 null인 경우 현재 용이성 계수를 그대로 반환
    if (qualityOfRecall == null) return easeFactor;

    // 기본 변화량 계산
    // 0.15를 기준으로 회상 품질에 따라 조정
    // 회상 품질이 높을수록 변화량이 커짐
    double change =
        0.15 - (5 - qualityOfRecall) * (0.1 + (5 - qualityOfRecall) * 0.02);

    // 이해도 향상 여부에 따라 변화량 조정
    // 이해도가 향상되었다면 변화량을 10% 증가, 그렇지 않으면 10% 감소
    change *= isUnderstandingImproved ? 1.1 : 0.9;

    // 최종 용이성 계수 계산
    // 1. 현재 용이성 계수에 변화량을 더함
    // 2. 실수 횟수에 따라 감소 (실수 1회당 0.05 감소)
    // 3. 이해도 향상 시 추가 보너스 (0.05 증가)
    // 4. 최소 용이성 계수(_minEaseFactor)보다 작아지지 않도록 보정
    return max(
        _minEaseFactor,
        easeFactor +
            change -
            (mistakeCount ?? 0) * 0.05 +
            (isUnderstandingImproved ? 0.05 : 0));
  }

  static int evaluateRecallQuality(Duration answerTime, bool isCorrect) {
    _logger.d('회상 품질 평가: answerTime=$answerTime, isCorrect=$isCorrect');

    // 오답인 경우 가장 낮은 품질 점수 0을 반환
    if (!isCorrect) return 0;

    if (kDebugMode) {
      // 디버그 모드: 분 단위
      if (answerTime.inMinutes < 1) return 5;
      if (answerTime.inMinutes < 3) return 4;
      if (answerTime.inMinutes < 10) return 3;
      return 2;
    } else {
      // 실제 모드: 일 단위 (기존 로직 유지)
      if (answerTime.inSeconds < 60) return 5; // 1분 미만: 최고 품질 (5점)

      if (answerTime.inSeconds < 180) return 4; // 1분 이상 3분 미만: 높은 품질 (4점)
      if (answerTime.inSeconds < 600) return 3; // 3분 이상 10분 미만: 중간 품질 (3점)
      return 2;
    }
  }
}
