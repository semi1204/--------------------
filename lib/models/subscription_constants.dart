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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'period': period,
      'originalPrice': originalPrice,
      'savePercent': savePercent,
      'isPopular': isPopular,
    };
  }

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      price: json['price'] ?? '',
      period: json['period'] ?? '',
      originalPrice: json['originalPrice'] ?? '',
      savePercent: json['savePercent'] ?? '',
      isPopular: json['isPopular'] ?? false,
    );
  }
}
