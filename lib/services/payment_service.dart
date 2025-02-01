import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:nursing_quiz_app_6/models/subscription_constants.dart';
import 'package:nursing_quiz_app_6/models/payment_history.dart';
import 'package:nursing_quiz_app_6/widgets/bottom_sheet/subscription_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:in_app_review/in_app_review.dart';
import 'dart:io';

class PaymentService extends ChangeNotifier {
  PaymentService({required Logger logger}) : _logger = logger;

  final Logger _logger;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late StreamSubscription<List<PurchaseDetails>> _purchaseUpdatedSubscription;

  bool get isIOS => Platform.isIOS;
  bool get isMacOs => Platform.isMacOS;

  static const String _subscriptionEndDateKey = 'subscription_end_date';
  static const String _subscriptionCacheKey = 'subscription_status';
  static const String _freeQuizCountKey = 'free_quiz_count';
  static const int maxFreeQuizzes = 10;

  SharedPreferences? _prefs;

  List<ProductDetails> _productDetails = [];

  Future<void> _initPrefs() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> initialize() async {
    await _initPrefs();
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      _logger.w('In-app purchases not available');
      return;
    }

    if (Platform.isIOS || Platform.isMacOS) {
      await _verifySubscriptionWithStoreKit();
    }

    final Set<String> kIds = {
      SubscriptionIds.monthlyIosId,
      SubscriptionIds.yearlyIosId,
    };

    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(kIds);
    if (response.error != null) {
      _logger.e('Error loading products: ${response.error}');
      return;
    }

    _productDetails = response.productDetails;
    _logger.i('Loaded ${_productDetails.length} products');

    _purchaseUpdatedSubscription =
        _inAppPurchase.purchaseStream.listen(_handlePurchaseUpdate);
  }

  Future<void> _verifySubscriptionWithStoreKit() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final InAppPurchaseStoreKitPlatformAddition storeKit = _inAppPurchase
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();

      final SKPaymentQueueWrapper queue = SKPaymentQueueWrapper();
      final transactions = await queue.transactions();

      bool hasActiveSubscription = false;

      for (final transaction in transactions) {
        if (transaction.payment == null ||
            transaction.transactionIdentifier == null) continue;

        if (transaction.transactionState ==
                SKPaymentTransactionStateWrapper.purchased ||
            transaction.transactionState ==
                SKPaymentTransactionStateWrapper.restored) {
          final bool isValidTransaction =
              await _validateStoreKitTransaction(transaction);
          if (isValidTransaction) {
            hasActiveSubscription = true;
            break;
          }
        }

        await queue.finishTransaction(transaction);
      }

      await _updateSubscriptionCache(hasActiveSubscription);
      _logger.i(
          'StoreKit verification completed - Has active subscription: $hasActiveSubscription');
    } catch (e) {
      _logger.e('Error during StoreKit verification: $e');
      await _updateSubscriptionCache(false);
    }
  }

  Future<bool> _validateStoreKitTransaction(
      SKPaymentTransactionWrapper transaction) async {
    try {
      final productId = transaction.payment.productIdentifier;
      final isYearly = productId == SubscriptionIds.yearlyId;
      final now = DateTime.now();

      final bool isSandbox = transaction.payment.simulatesAskToBuyInSandbox;
      final Duration subscriptionDuration = isSandbox
          ? (isYearly ? const Duration(minutes: 5) : const Duration(minutes: 3))
          : (isYearly ? const Duration(days: 365) : const Duration(days: 30));

      await _firestore
          .collection('subscription_validations')
          .doc(_auth.currentUser?.uid)
          .set({
        'transactionId': transaction.transactionIdentifier,
        'productId': productId,
        'validatedAt': FieldValue.serverTimestamp(),
        'isSandbox': isSandbox,
        'expiresAt': Timestamp.fromDate(now.add(subscriptionDuration)),
      });

      return true;
    } catch (e) {
      _logger.e('Transaction validation error: $e');
      return false;
    }
  }

  Future<void> _updateSubscriptionCache(bool isSubscribed) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _prefs?.setBool('${_subscriptionCacheKey}_${user.uid}', isSubscribed);
    await _prefs?.setInt(
      '${_subscriptionCacheKey}_${user.uid}_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );

    _logger.i('Updated subscription cache - Is subscribed: $isSubscribed');
    notifyListeners();
  }

  Future<bool> checkSubscriptionStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      // 1. Check SharedPreferences cache first
      await _initPrefs();
      final cachedStatus =
          _prefs?.getBool('${_subscriptionCacheKey}_${user.uid}');
      final cachedTimestamp =
          _prefs?.getInt('${_subscriptionCacheKey}_${user.uid}_timestamp');

      if (cachedStatus != null && cachedTimestamp != null) {
        final cacheAge = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(cachedTimestamp));
        if (cacheAge < const Duration(minutes: 30)) {
          return cachedStatus;
        }
      }

      // 2. Check Firestore only if cache miss or expired
      final doc =
          await _firestore.collection('subscriptions').doc(user.uid).get();
      if (doc.exists) {
        final serverEndDate = (doc.data()?['endDate'] as Timestamp).toDate();
        final isActive = DateTime.now().isBefore(serverEndDate);

        // Cache the result in SharedPreferences
        await _prefs?.setBool('${_subscriptionCacheKey}_${user.uid}', isActive);
        await _prefs?.setInt('${_subscriptionCacheKey}_${user.uid}_timestamp',
            DateTime.now().millisecondsSinceEpoch);

        return isActive;
      }

      return false;
    } catch (e) {
      _logger.e('Error checking subscription status: $e');
      return false;
    }
  }

  Future<bool> hasActiveSubscription() async {
    await _initPrefs();
    final endDateMillis = _prefs?.getInt(_subscriptionEndDateKey);
    if (endDateMillis == null) return false;

    final endDate = DateTime.fromMillisecondsSinceEpoch(endDateMillis);
    final isActive = DateTime.now().isBefore(endDate);

    _logger.d(
        'Local subscription status: ${isActive ? 'active' : 'inactive'} until $endDate');
    return isActive;
  }

  Future<bool> canAttemptQuiz() async {
    try {
      if (await hasActiveSubscription()) return true;

      final currentCount = _prefs?.getInt(_freeQuizCountKey) ?? 0;
      return currentCount < maxFreeQuizzes;
    } catch (e) {
      _logger.e('Error checking quiz attempt availability: $e');
      return false;
    }
  }

  Future<void> incrementQuizAttempt() async {
    try {
      if (await hasActiveSubscription()) return;

      final currentCount = _prefs?.getInt(_freeQuizCountKey) ?? 0;
      final newCount = currentCount + 1;

      await _prefs?.setInt(_freeQuizCountKey, newCount);
      _logger.i('Incremented quiz attempt count to: $newCount');

      // 10번째 퀴즈 시도시 리뷰 요청
      if (newCount == maxFreeQuizzes) {
        try {
          final InAppReview inAppReview = InAppReview.instance;
          if (await inAppReview.isAvailable()) {
            _logger.i('Requesting app review after max free quizzes');
            await inAppReview.requestReview();
          }
        } catch (e) {
          _logger.e('Error requesting app review: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      _logger.e('Error incrementing quiz attempt count: $e');
    }
  }

  Future<int> getRemainingQuizzes() async {
    if (await hasActiveSubscription()) return -1;

    final currentCount = _prefs?.getInt(_freeQuizCountKey) ?? 0;
    return maxFreeQuizzes - currentCount;
  }

  Future<void> _handlePurchaseUpdate(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _logger.i('Purchase pending: ${purchaseDetails.productID}');
        // Ask to Buy 상태 처리
        if (Platform.isIOS || Platform.isMacOS) {
          _handleAskToBuyStatus(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        _logger.e('Purchase error: ${purchaseDetails.error}');
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        final bool valid = await _verifyPurchase(purchaseDetails);
        if (valid) {
          await _updateSubscriptionStatus(purchaseDetails);
          _logger.i('Purchase verified and completed');
        } else {
          _logger.e('Purchase verification failed');
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        _logger.i('Purchase canceled: ${purchaseDetails.productID}');
        // Ask to Buy 거절 처리
        if (Platform.isIOS || Platform.isMacOS) {
          _handleAskToBuyRejection(purchaseDetails);
        }
      }
    }
    notifyListeners();
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final SKPaymentQueueWrapper paymentQueue = SKPaymentQueueWrapper();
        final List<SKPaymentTransactionWrapper> transactions =
            await paymentQueue.transactions();

        final matchingTransaction = transactions.firstWhere(
          (transaction) =>
              transaction.transactionIdentifier == purchaseDetails.purchaseID,
          orElse: () => throw Exception('Transaction not found in StoreKit'),
        );

        if (matchingTransaction.transactionState !=
                SKPaymentTransactionStateWrapper.purchased &&
            matchingTransaction.transactionState !=
                SKPaymentTransactionStateWrapper.restored) {
          _logger.w(
              'Invalid transaction state: ${matchingTransaction.transactionState}');
          return false;
        }

        if (purchaseDetails.verificationData.source == 'app_store_sandbox') {
          _logger.i('Sandbox purchase detected, applying sandbox verification');
          final bool isValidSandbox =
              await _verifySandboxPurchase(matchingTransaction);
          if (!isValidSandbox) {
            _logger.w('Sandbox verification failed');
            return false;
          }
        }
      }

      final verificationData = purchaseDetails.verificationData;
      final response = await _verifyWithServer(
        token: verificationData.serverVerificationData,
        productId: purchaseDetails.productID,
        source: verificationData.source,
      );

      _logger.i('Purchase verification completed - Success: $response');
      return response;
    } catch (e) {
      _logger.e('Purchase verification error: $e');
      return false;
    }
  }

  Future<bool> _verifySandboxPurchase(
      SKPaymentTransactionWrapper transaction) async {
    try {
      if (transaction.payment == null ||
          transaction.transactionIdentifier == null ||
          transaction.payment.productIdentifier.isEmpty) {
        _logger.w('Invalid sandbox transaction details');
        return false;
      }

      final queue = SKPaymentQueueWrapper();
      final transactions = await queue.transactions();

      final exists = transactions.any((t) =>
          t.transactionIdentifier == transaction.transactionIdentifier &&
          t.payment.productIdentifier ==
              transaction.payment.productIdentifier &&
          (t.transactionState == SKPaymentTransactionStateWrapper.purchased ||
              t.transactionState == SKPaymentTransactionStateWrapper.restored));

      if (!exists) {
        _logger.w(
            'Transaction not found in current payment queue or invalid state');
        return false;
      }

      _logger.i('Sandbox verification completed successfully');
      return true;
    } catch (e) {
      _logger.e('Sandbox verification error: $e');
      return false;
    }
  }

  Future<bool> _verifyWithServer({
    required String token,
    required String productId,
    required String source,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('purchase_verifications').doc(user.uid).set({
        'token': token,
        'productId': productId,
        'source': source,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _logger.e('Server verification error: $e');
      return false;
    }
  }

  Future<void> _updateSubscriptionStatus(PurchaseDetails purchase) async {
    final DateTime now = DateTime.now();
    final bool isYearlySubscription =
        purchase.productID == SubscriptionIds.yearlyId;
    final bool isSandbox = Platform.isIOS
        ? purchase.verificationData.source == 'app_store_sandbox'
        : false;

    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('subscriptions').doc(user.uid).set({
        'startDate': Timestamp.fromDate(now),
        'purchaseToken': purchase.purchaseID,
        'productId': purchase.productID,
        'isYearlySubscription': isYearlySubscription,
        'updatedAt': FieldValue.serverTimestamp(),
        'userEmail': user.email,
        'isSandbox': isSandbox,
      });

      await _updateSubscriptionCache(true);

      final productDetails = _productDetails.firstWhere(
        (p) => p.id == purchase.productID,
        orElse: () => throw Exception('Product details not found'),
      );

      final paymentHistory = PaymentHistory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        subscriptionId: purchase.productID,
        amount: double.parse(
            productDetails.price.replaceAll(RegExp(r'[^\d.]'), '')),
        date: now,
        status: PaymentStatus.success,
        paymentMethod: Platform.isIOS ? 'App Store' : 'Google Play',
        transactionId: purchase.purchaseID ?? '',
        userEmail: user.email,
        isSandbox: isSandbox,
      );

      await _firestore
          .collection('payment_history')
          .doc(paymentHistory.id)
          .set(paymentHistory.toFirestore());

      _logger.i(
          'Updated subscription status - Sandbox: ${paymentHistory.isSandbox}');
    }
  }

  Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    if (_productDetails.isEmpty) {
      _logger.w('No product details available, trying to reload...');
      await initialize(); // 상품 정보 다시 로드 시도
    }

    List<SubscriptionPlan> plans = [];

    try {
      final monthlyProduct = _productDetails.firstWhere(
        (p) => p.id == SubscriptionIds.monthlyId,
        orElse: () => throw Exception('Monthly subscription product not found'),
      );

      plans.add(SubscriptionPlan(
        id: monthlyProduct.id,
        title: '월간 구독',
        description: '매월 결제 갱신',
        price: monthlyProduct.price,
        period: '월',
        originalPrice: monthlyProduct.price,
        savePercent: '0',
      ));

      final yearlyProduct = _productDetails.firstWhere(
        (p) => p.id == SubscriptionIds.yearlyId,
        orElse: () => throw Exception('Yearly subscription product not found'),
      );

      plans.add(SubscriptionPlan(
        id: yearlyProduct.id,
        title: '연간 구독',
        description: '연간 결제 시 70% 할인',
        price: yearlyProduct.price,
        period: '년',
        originalPrice: monthlyProduct.price,
        savePercent: '70%',
        isPopular: true,
      ));

      _logger.i('Created ${plans.length} subscription plans');
    } catch (e) {
      _logger.e('Error creating subscription plans: $e');
    }

    return plans;
  }

  Future<void> showEnhancedSubscriptionDialog(BuildContext context) async {
    if (!context.mounted) return;

    _logger.i('Fetching subscription plans...');
    final plans = await getSubscriptionPlans();
    _logger.i('Fetched ${plans.length} plans');

    if (plans.isEmpty) {
      _logger.w('No subscription plans available');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구독 상품을 불러올 수 없습니다.')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SubscriptionBottomSheet(
        plans: plans,
        onSubscriptionSelected: _handleSubscription,
      ),
    );
  }

  Future<void> _handleSubscription(
      BuildContext context, SubscriptionPlan plan) async {
    try {
      final ProductDetails productDetails =
          await _getSubscriptionProduct(plan.id);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext ctx) =>
            const Center(child: CircularProgressIndicator()),
      );

      // Clear any pending transactions before initiating new purchase
      if (Platform.isIOS || Platform.isMacOS) {
        final SKPaymentQueueWrapper wrapper = SKPaymentQueueWrapper();
        final List<SKPaymentTransactionWrapper> transactions =
            await wrapper.transactions();

        // Complete any pending transactions for this product
        for (final transaction in transactions) {
          if (transaction.payment.productIdentifier == productDetails.id) {
            await wrapper.finishTransaction(transaction);
            _logger.i(
                'Completed pending transaction: ${transaction.transactionIdentifier}');
          }
        }
      }

      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        throw Exception('Store not available');
      }

      // For StoreKit deferred payments (Ask to Buy)
      if ((Platform.isIOS || Platform.isMacOS) &&
          productDetails is AppStoreProductDetails) {
        _logger.i('Initiating StoreKit payment with Ask to Buy support');

        final payment = SKPaymentWrapper(
          productIdentifier: productDetails.id,
          quantity: 1,
          applicationUsername: _auth.currentUser?.uid,
          simulatesAskToBuyInSandbox: true, // Enable Ask to Buy in sandbox
        );

        final storeKit = SKPaymentQueueWrapper();
        await storeKit.addPayment(payment);

        if (context.mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('결제 요청이 전송되었습니다. 승인을 기다려주세요.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      await _inAppPurchase.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: productDetails,
          applicationUserName: _auth.currentUser?.uid,
        ),
      );

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }
    } catch (e) {
      _logger.e('Error initiating purchase: $e');
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        showDialog(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('구독 오류'),
            content: Text('구독 처리 중 오류가 발생했습니다: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<ProductDetails> _getSubscriptionProduct(String productId) async {
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails({productId});

    if (response.notFoundIDs.isNotEmpty) {
      throw Exception('Subscription product not found');
    }

    if (response.productDetails.isEmpty) {
      throw Exception('No subscription products available');
    }

    return response.productDetails.first;
  }

  Future<void> restorePurchases(BuildContext context) async {
    try {
      _logger.i('Starting purchase restoration');

      if (!await _inAppPurchase.isAvailable()) {
        throw Exception('Store not available');
      }

      await _inAppPurchase.restorePurchases();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구매 내역을 복원했습니다.')),
        );
      }

      _logger.i('Purchase restoration completed');
    } catch (e) {
      _logger.e('Errosr restoring purchases: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구매 내역 복원에 실패했습니다.')),
        );
      }
    }
  }

  void _handleAskToBuyStatus(PurchaseDetails purchaseDetails) {
    _logger.i('Ask to Buy request pending for: ${purchaseDetails.productID}');
    // 여기서 필요한 경우 UI 업데이트나 사용자에게 알림을 보낼 수 있습니다.
  }

  void _handleAskToBuyRejection(PurchaseDetails purchaseDetails) {
    _logger.i('Ask to Buy request rejected for: ${purchaseDetails.productID}');
    // 여기서 필요한 경우 UI 업데이트나 사용자에게 알림을 보낼 수 있습니다.
  }

  @override
  void dispose() {
    _purchaseUpdatedSubscription.cancel();
    super.dispose();
  }
}
