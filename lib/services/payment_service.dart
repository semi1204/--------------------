import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class PaymentService extends ChangeNotifier {
  PaymentService({required Logger logger}) : _logger = logger;

  final Logger _logger;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late StreamSubscription<List<PurchaseDetails>> _purchaseUpdatedSubscription;

  static const String _subscriptionEndDateKey = 'subscription_end_date';
  static const String _freeQuizCountKey = 'free_quiz_count';
  static const String _yearlySubscriptionId =
      'com.nursingquiz.subscription.yearly';
  static const int maxFreeQuizzes = 10;

  late final SharedPreferences _prefs;

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> initialize() async {
    await _initPrefs();
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      _logger.w('In-app purchases not available');
      return;
    }

    const Set<String> kIds = {_yearlySubscriptionId};
    await _inAppPurchase.queryProductDetails(kIds);
    _purchaseUpdatedSubscription =
        _inAppPurchase.purchaseStream.listen(_handlePurchaseUpdate);
  }

  Future<bool> checkSubscriptionStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // 로컬 체크
      final localStatus = await hasActiveSubscription();

      // 서버 체크
      final doc =
          await _firestore.collection('subscriptions').doc(user.uid).get();

      if (!doc.exists) return localStatus;

      final serverEndDate = (doc.data()?['endDate'] as Timestamp).toDate();
      final isActiveOnServer = DateTime.now().isBefore(serverEndDate);

      // 로컬과 서버 상태가 다르면 로컬 상태 업데이트
      if (localStatus != isActiveOnServer) {
        await _prefs.setInt(
          _subscriptionEndDateKey,
          serverEndDate.millisecondsSinceEpoch,
        );
        notifyListeners();
      }

      return isActiveOnServer;
    } catch (e) {
      _logger.e('Error checking subscription status: $e');
      return await hasActiveSubscription(); // 서버 체크 실패시 로컬 상태 반환
    }
  }

  Future<bool> hasActiveSubscription() async {
    try {
      await _initPrefs();
      final subscriptionEndDate = _prefs.getInt(_subscriptionEndDateKey);

      if (subscriptionEndDate == null) return false;

      final endDate = DateTime.fromMillisecondsSinceEpoch(subscriptionEndDate);
      return DateTime.now().isBefore(endDate);
    } catch (e) {
      _logger.e('Error checking local subscription status: $e');
      return false;
    }
  }

  Future<bool> canAttemptQuiz() async {
    try {
      if (await hasActiveSubscription()) return true;

      final currentCount = _prefs.getInt(_freeQuizCountKey) ?? 0;

      _logger.i('Current quiz attempt count: $currentCount');
      return currentCount < maxFreeQuizzes;
    } catch (e) {
      _logger.e('Error checking quiz attempt availability: $e');
      return false;
    }
  }

  Future<void> incrementQuizAttempt() async {
    try {
      if (await hasActiveSubscription()) return;

      final currentCount = _prefs.getInt(_freeQuizCountKey) ?? 0;
      final newCount = currentCount + 1;

      await _prefs.setInt(_freeQuizCountKey, newCount);
      _logger.i('Incremented quiz attempt count to: $newCount');

      notifyListeners();
    } catch (e) {
      _logger.e('Error incrementing quiz attempt count: $e');
    }
  }

  Future<int> getRemainingQuizzes() async {
    if (await hasActiveSubscription()) return -1;

    final currentCount = _prefs.getInt(_freeQuizCountKey) ?? 0;
    return maxFreeQuizzes - currentCount;
  }

  Future<void> _handlePurchaseUpdate(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _logger.i('Purchase pending: ${purchaseDetails.productID}');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        _logger.e('Purchase error: ${purchaseDetails.error}');
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Verify the purchase before delivering the product
        final bool valid = await _verifyPurchase(purchaseDetails);
        if (valid) {
          await _updateSubscriptionStatus(purchaseDetails);
          _logger.i('Purchase verified and completed');
        } else {
          _logger.e('Purchase verification failed');
        }

        // Complete the purchase regardless of verification result
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        _logger.i('Purchase canceled: ${purchaseDetails.productID}');
      }
    }
    notifyListeners();
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // TODO: Implement your server-side purchase verification
    // You should verify the purchase with your backend server
    try {
      final verificationData = purchaseDetails.verificationData;
      final response = await _verifyWithServer(
        token: verificationData.serverVerificationData,
        productId: purchaseDetails.productID,
        source: verificationData.source,
      );
      return response;
    } catch (e) {
      _logger.e('Purchase verification error: $e');
      return false;
    }
  }

  Future<bool> _verifyWithServer({
    required String token,
    required String productId,
    required String source,
  }) async {
    try {
      // TODO: Implement your server verification logic
      // This is where you would make an API call to your backend
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('purchase_verifications').doc(user.uid).set({
        'token': token,
        'productId': productId,
        'source': source,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true; // Return true only after proper verification
    } catch (e) {
      _logger.e('Server verification error: $e');
      return false;
    }
  }

  Future<void> _updateSubscriptionStatus(PurchaseDetails purchase) async {
    final endDate = DateTime.now().add(const Duration(days: 365));

    // 로컬 저장
    await _prefs.setInt(
      _subscriptionEndDateKey,
      endDate.millisecondsSinceEpoch,
    );

    // 서버 저장
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('subscriptions').doc(user.uid).set({
        'endDate': Timestamp.fromDate(endDate),
        'purchaseToken': purchase.purchaseID,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> navigateToSubscriptionPage(BuildContext context) async {
    _logger.i('Navigating to subscription page');
    try {
      final ProductDetails productDetails = await _getSubscriptionProduct();

      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        throw Exception('Store not available');
      }

      await _inAppPurchase.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: productDetails,
          applicationUserName: _auth.currentUser?.uid,
        ),
      );

      // Hide loading indicator
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      _logger.i('Successfully initiated purchase flow');
    } catch (e) {
      _logger.e('Error initiating purchase: $e');
      if (context.mounted) {
        Navigator.of(context).pop(); // Hide loading indicator
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('구독 오류'),
            content: Text('구독 처리 중 오류가 발생했습니다: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<ProductDetails> _getSubscriptionProduct() async {
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails({_yearlySubscriptionId});

    if (response.notFoundIDs.isNotEmpty) {
      throw Exception('Subscription product not found');
    }

    if (response.productDetails.isEmpty) {
      throw Exception('No subscription products available');
    }

    return response.productDetails.first;
  }

  void showSubscriptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('구독이 필요합니다'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('무료로 제공되는 10문제를 모두 사용하셨습니다.'),
            SizedBox(height: 8),
            Text('구독하시면 무제한으로 문제를 풀 수 있습니다.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await navigateToSubscriptionPage(context);
            },
            child: const Text('구독하기'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _purchaseUpdatedSubscription.cancel();
    super.dispose();
  }
}
