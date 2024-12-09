import 'package:nursing_quiz_app_6/utils/anki_algorithm.dart';

class QuizUserData {
  int correct;
  int total;
  double accuracy;
  int interval;
  double easeFactor;
  int consecutiveCorrect;
  DateTime? nextReviewDate; // nullable로 변경
  int mistakeCount;
  DateTime lastAnswered;
  int? selectedOptionIndex;
  bool isUnderstandingImproved;
  bool markedForReview;

  QuizUserData({
    this.correct = 0,
    this.total = 0,
    this.accuracy = 0.0,
    this.interval = 0,
    this.easeFactor = 2.5,
    this.consecutiveCorrect = 0,
    required this.lastAnswered,
    this.nextReviewDate,
    this.mistakeCount = 0,
    this.selectedOptionIndex,
    this.isUnderstandingImproved = false,
    this.markedForReview = false,
  });

  Map<String, dynamic> toJson() => {
        'correct': correct,
        'total': total,
        'accuracy': accuracy,
        'interval': interval,
        'easeFactor': easeFactor,
        'consecutiveCorrect': consecutiveCorrect,
        'nextReviewDate': nextReviewDate?.toIso8601String(),
        'mistakeCount': mistakeCount,
        'lastAnswered': lastAnswered.toIso8601String(),
        'selectedOptionIndex': selectedOptionIndex,
        'isUnderstandingImproved': isUnderstandingImproved,
        'markedForReview': markedForReview,
      };

  factory QuizUserData.fromJson(Map<String, dynamic> json) {
    try {
      DateTime parseDateTime(dynamic value) {
        if (value == null) return DateTime.now();
        if (value is String) {
          try {
            return DateTime.parse(value);
          } catch (e) {
            return DateTime.now();
          }
        }
        return DateTime.now();
      }

      return QuizUserData(
        correct: json['correct']?.toInt() ?? 0,
        total: json['total']?.toInt() ?? 0,
        accuracy: (json['accuracy'] ?? 0.0).toDouble(),
        interval: json['interval']?.toInt() ?? 0,
        easeFactor: (json['easeFactor'] ?? 2.5).toDouble(),
        consecutiveCorrect: json['consecutiveCorrect']?.toInt() ?? 0,
        nextReviewDate: json['nextReviewDate'] != null
            ? parseDateTime(json['nextReviewDate'])
            : null,
        mistakeCount: json['mistakeCount']?.toInt() ?? 0,
        lastAnswered: parseDateTime(json['lastAnswered']),
        selectedOptionIndex: json['selectedOptionIndex']?.toInt(),
        isUnderstandingImproved: json['isUnderstandingImproved'] ?? false,
        markedForReview: json['markedForReview'] ?? false,
      );
    } catch (e) {
      // 데이터 변환 실패시 기본값으로 초기화
      return QuizUserData(lastAnswered: DateTime.now());
    }
  }
}
