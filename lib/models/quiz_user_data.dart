import 'package:nursing_quiz_app_6/utils/anki_algorithm.dart';

class QuizUserData {
  int correct;
  int total;
  double accuracy;
  int interval;
  double easeFactor;
  int consecutiveCorrect;
  DateTime nextReviewDate;
  int mistakeCount;
  DateTime lastAnswered;
  int? selectedOptionIndex;
  bool isUnderstandingImproved;
  bool markedForReview;

  QuizUserData({
    this.correct = 0,
    this.total = 0,
    this.accuracy = 0.0,
    this.interval = AnkiAlgorithm.initialInterval,
    this.easeFactor = AnkiAlgorithm.defaultEaseFactor,
    this.consecutiveCorrect = 0,
    required this.nextReviewDate,
    this.mistakeCount = 0,
    required this.lastAnswered,
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
        'nextReviewDate': nextReviewDate.toIso8601String(),
        'mistakeCount': mistakeCount,
        'lastAnswered': lastAnswered.toIso8601String(),
        'selectedOptionIndex': selectedOptionIndex,
        'isUnderstandingImproved': isUnderstandingImproved,
        'markedForReview': markedForReview,
      };

  factory QuizUserData.fromJson(Map<String, dynamic> json) => QuizUserData(
        correct: json['correct'] ?? 0,
        total: json['total'] ?? 0,
        accuracy: json['accuracy'] ?? 0.0,
        interval: json['interval'] ?? AnkiAlgorithm.initialInterval,
        easeFactor: json['easeFactor'] ?? AnkiAlgorithm.defaultEaseFactor,
        consecutiveCorrect: json['consecutiveCorrect'] ?? 0,
        nextReviewDate: DateTime.parse(
            json['nextReviewDate'] ?? DateTime.now().toIso8601String()),
        mistakeCount: json['mistakeCount'] ?? 0,
        lastAnswered: DateTime.parse(
            json['lastAnswered'] ?? DateTime.now().toIso8601String()),
        selectedOptionIndex: json['selectedOptionIndex'],
        isUnderstandingImproved: json['isUnderstandingImproved'] ?? false,
        markedForReview: json['markedForReview'] ?? false,
      );
}
