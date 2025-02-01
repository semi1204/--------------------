import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus {
  success,
  failed,
  pending,
  refunded,
}

class PaymentHistory {
  final String id;
  final String userId;
  final String subscriptionId;
  final double amount;
  final DateTime date;
  final PaymentStatus status;
  final String paymentMethod;
  final String transactionId;
  final String? userEmail;
  final bool isSandbox;

  PaymentHistory({
    required this.id,
    required this.userId,
    required this.subscriptionId,
    required this.amount,
    required this.date,
    required this.status,
    required this.paymentMethod,
    required this.transactionId,
    this.userEmail,
    this.isSandbox = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'subscriptionId': subscriptionId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'status': status.toString(),
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'userEmail': userEmail,
      'isSandbox': isSandbox,
    };
  }

  factory PaymentHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentHistory(
      id: doc.id,
      userId: data['userId'] ?? '',
      subscriptionId: data['subscriptionId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      status: PaymentStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      paymentMethod: data['paymentMethod'] ?? '',
      transactionId: data['transactionId'] ?? '',
      userEmail: data['userEmail'],
      isSandbox: data['isSandbox'] ?? false,
    );
  }
}
