import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:logger/logger.dart';

class PaymentService {
  final Logger _logger = Logger();
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  List<ProductDetails> _products = [];

  Future<void> showSubscriptionDialog(BuildContext context) async {
    _logger.i('Showing subscription dialog');
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _showAppleSubscription(context);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      await _showGoogleSubscription(context);
    } else {
      _logger.w('Unsupported platform for in-app purchases');
    }
  }

  Future<void> initializePayment() async {
    _logger.i('Initializing payment service');
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      _logger.w('In-app purchases not available');
      return;
    }

    const Set<String> kIds = {'subscription_monthly', 'subscription_yearly'};
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(kIds);
    if (response.notFoundIDs.isNotEmpty) {
      _logger.w('Some products were not found: ${response.notFoundIDs}');
    }
    _products = response.productDetails;
  }

  Future<bool> checkSubscriptionStatus(String userId) async {
    _logger.i('Checking subscription status for user: $userId');
    final purchases = await _inAppPurchase.purchaseStream.first;
    return purchases.any((purchase) =>
        purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored);
  }

  Future<void> _showAppleSubscription(BuildContext context) async {
    _logger.i('Showing Apple subscription options');
    await _showSubscriptionOptions(context);
  }

  Future<void> _showGoogleSubscription(BuildContext context) async {
    _logger.i('Showing Google subscription options');
    await _showSubscriptionOptions(context);
  }

  Future<void> restorePurchases() async {
    _logger.i('Attempting to restore purchases');
    await _inAppPurchase.restorePurchases();
  }

  void listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        _logger.i('Subscription purchased or restored');
      }
    }
  }

  Future<void> _showSubscriptionOptions(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('구독 옵션'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _products.map((product) {
              return ListTile(
                title: Text(product.title),
                subtitle: Text(product.description),
                trailing: Text(product.price),
                onTap: () => _purchaseSubscription(product),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _purchaseSubscription(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }
}
