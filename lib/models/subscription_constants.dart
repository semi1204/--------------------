import 'dart:io' show Platform;

class SubscriptionIds {
  static const String monthlyIosId = 'com.example.nursingQuizApp.monthly';
  static const String yearlyIosId = 'com.example.nursingQuizApp.yearly';
  static const String monthlyAndroidId = 'monthly_subscription';
  static const String yearlyAndroidId = 'yearly_subscription';

  static String get monthlyId =>
      Platform.isIOS ? monthlyIosId : monthlyAndroidId;
  static String get yearlyId => Platform.isIOS ? yearlyIosId : yearlyAndroidId;
}

class SubscriptionPlan {
  final String id;
  final String title;
  final String description;
  final String price;
  final String period;
  final String originalPrice;
  final String savePercent;
  final bool isPopular;

  SubscriptionPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.period,
    required this.originalPrice,
    required this.savePercent,
    this.isPopular = false,
  });
}