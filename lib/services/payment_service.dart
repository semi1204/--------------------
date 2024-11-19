import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:nursing_quiz_app_6/models/subscription_constants.dart';
import 'package:nursing_quiz_app_6/utils/constants.dart';
import 'package:nursing_quiz_app_6/widgets/bottom_sheet/subscription_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:in_app_review/in_app_review.dart';

class PaymentService extends ChangeNotifier {
  PaymentService({required Logger logger}) : _logger = logger;

  final Logger _logger;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late StreamSubscription<List<PurchaseDetails>> _purchaseUpdatedSubscription;

  static const String _subscriptionEndDateKey = 'subscription_end_date';
  static const String _freeQuizCountKey = 'free_quiz_count';
  static const int maxFreeQuizzes = 10;

  SharedPreferences? _prefs;

  // 상품 정보를 저장할 변수 추가
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

    const Set<String> kIds = {
      'com.example.nursingQuizApp.yearly',
      'com.example.nursingQuizApp.monthly',
    };

    // 상품 정보 조회 및 저장
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

  Future<bool> checkSubscriptionStatus() async {
    try {
      // 유저 정보 가져오기
      final user = _auth.currentUser;
      if (user == null) return false;
      // admin 상태 로그 출력
      _logger.d('Checking admin status for user: ${user.email}');

      // 이메일로 admin 체크
      if (user.email == ADMIN_EMAIL) {
        _logger.i('User is admin - granting access');
        return true;
      }

      // 로컬 상태 확인
      final localStatus = await hasActiveSubscription();
      // firestore에서 유저 정보 가져오기
      final doc =
          await _firestore.collection('subscriptions').doc(user.uid).get();
      // firestore에서 유저 정보가 없으면 로컬 상태 반환
      if (!doc.exists) return localStatus;

      // firestore에서 유저 정보 가져오기
      final serverEndDate = (doc.data()?['endDate'] as Timestamp).toDate();
      // firestore에서 유저 정보가 있으면 서버 상태 확인
      final isActiveOnServer = DateTime.now().isBefore(serverEndDate);

      // 로컬과 서버 상태가 다르면 로컬 상태 업데이트
      if (localStatus != isActiveOnServer) {
        await _prefs?.setInt(
          _subscriptionEndDateKey,
          serverEndDate.millisecondsSinceEpoch,
        );
        notifyListeners();
      }

      return isActiveOnServer;
    } catch (e) {
      _logger.e('Error checking subscription status: $e');
      return await hasActiveSubscription();
    }
  }

  Future<bool> hasActiveSubscription() async {
    try {
      await _initPrefs();
      final subscriptionEndDate = _prefs?.getInt(_subscriptionEndDateKey);

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
      }
    }
    notifyListeners();
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
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
    final endDate = DateTime.now().add(
      purchase.productID == SubscriptionIds.monthlyId
          ? const Duration(days: 30)
          : const Duration(days: 365),
    );

    // 로컬 저장
    await _prefs?.setInt(
      _subscriptionEndDateKey,
      endDate.millisecondsSinceEpoch,
    );

    // 서버 저장
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('subscriptions').doc(user.uid).set({
        'endDate': Timestamp.fromDate(endDate),
        'purchaseToken': purchase.purchaseID,
        'productId': purchase.productID,
        'updatedAt': FieldValue.serverTimestamp(),
      });
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

      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _logger.e('Error initiating purchase: $e');
      if (context.mounted) {
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

  @override
  void dispose() {
    _purchaseUpdatedSubscription.cancel();
    super.dispose();
  }
}
