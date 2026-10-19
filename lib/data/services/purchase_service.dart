import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../core/constants/app_constants.dart';
import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';

class PurchaseService {
  PurchaseService(this._settingsRepo);

  final SettingsRepository _settingsRepo;
  final InAppPurchase _iap = InAppPurchase.instance;
  static const _manageChannel = MethodChannel('folio/iap');

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  bool _available = false;
  final Map<String, ProductDetails> _products = {};
  GooglePlayPurchaseDetails? _androidActivePurchase;

  bool get isAvailable => _available;
  ProductDetails? get monthlyProduct =>
      _products[AppConstants.premiumMonthlyId];
  ProductDetails? get yearlyProduct => _products[AppConstants.premiumYearlyId];

  String get monthlyPriceLabel =>
      monthlyProduct?.price ?? AppConstants.premiumMonthlyPriceLabel;
  String get yearlyPriceLabel =>
      yearlyProduct?.price ?? AppConstants.premiumYearlyPriceLabel;

  Future<void> init() async {
    _available = await _iap.isAvailable();
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('IAP stream error: $e'),
    );

    if (_available) {
      final response = await _iap.queryProductDetails(
        AppConstants.premiumProductIds,
      );
      for (final product in response.productDetails) {
        _products.putIfAbsent(product.id, () => product);
      }
      if (Platform.isAndroid) {
        await _syncAndroidPurchases();
      }
    }
    await _dropExpiredLocalEntitlement();
    _changes.add(null);
  }

  Future<void> _syncAndroidPurchases() async {
    try {
      final addition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final past = await addition.queryPastPurchases();
      await _onPurchases(past.pastPurchases);
    } catch (e) {
      debugPrint('queryPastPurchases failed: $e');
    }
  }

  Future<bool> buyMonthly() =>
      _buy(AppConstants.premiumMonthlyId, isUpgrade: false);

  Future<bool> buyYearly() async {
    if (Platform.isAndroid) {
      await _syncAndroidPurchases();
    }
    final upgrading = _settingsRepo.read().isMonthlyPro;
    return _buy(AppConstants.premiumYearlyId, isUpgrade: upgrading);
  }

  Future<bool> _buy(String productId, {required bool isUpgrade}) async {
    final product = _products[productId];
    if (!_available || product == null) {
      if (kDebugMode) {
        await _activate(productId, DateTime.now());
        _changes.add(null);
        return true;
      }
      throw StateError(
        'This plan is not available in the store yet. Check the product IDs.',
      );
    }

    PurchaseParam param;
    if (Platform.isAndroid) {
      final playProduct = product is GooglePlayProductDetails ? product : null;
      ChangeSubscriptionParam? change;
      if (isUpgrade && _androidActivePurchase != null) {
        change = ChangeSubscriptionParam(
          oldPurchaseDetails: _androidActivePurchase!,
          replacementMode: ReplacementMode.chargeProratedPrice,
        );
      }
      param = GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: playProduct?.offerToken,
        changeSubscriptionParam: change,
      );
    } else {
      param = PurchaseParam(productDetails: product);
    }

    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() async {
    if (!_available) {
      _changes.add(null);
      return;
    }
    if (Platform.isAndroid) {
      await _syncAndroidPurchases();
    }
    await _iap.restorePurchases();
    await _dropExpiredLocalEntitlement();
    _changes.add(null);
  }

  /// Opens Play Store / App Store subscription management.
  /// Apps cannot cancel a subscription themselves.
  Future<void> openManageSubscriptions() async {
    final sku = _settingsRepo.read().subscriptionProductId ??
        AppConstants.premiumMonthlyId;
    await _manageChannel.invokeMethod<void>(
      'openManageSubscriptions',
      {'sku': sku},
    );
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!AppConstants.premiumProductIds.contains(purchase.productID)) {
        continue;
      }

      if (purchase is GooglePlayPurchaseDetails) {
        _rememberAndroidPurchase(purchase);
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _activate(
          purchase.productID,
          _parseTransactionDate(purchase.transactionDate),
        );
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('IAP error: ${purchase.error}');
      }
    }
    _changes.add(null);
  }

  void _rememberAndroidPurchase(GooglePlayPurchaseDetails purchase) {
    final current = _androidActivePurchase;
    if (current == null) {
      _androidActivePurchase = purchase;
      return;
    }
    if (purchase.productID == AppConstants.premiumYearlyId) {
      _androidActivePurchase = purchase;
    } else if (current.productID != AppConstants.premiumYearlyId) {
      _androidActivePurchase = purchase;
    }
  }

  DateTime _parseTransactionDate(String? raw) {
    if (raw == null || raw.isEmpty) return DateTime.now();
    final n = int.tryParse(raw);
    if (n != null) {
      if (n > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n);
      }
      if (n > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n * 1000);
      }
    }
    return DateTime.tryParse(raw) ?? DateTime.now();
  }

  Duration _periodFor(String productId) {
    return productId == AppConstants.premiumYearlyId
        ? const Duration(days: 365)
        : const Duration(days: 30);
  }

  DateTime _expiryFrom(String productId, DateTime start, DateTime now) {
    final period = _periodFor(productId);
    var expiry = start.add(period);
    while (!expiry.isAfter(now)) {
      expiry = expiry.add(period);
    }
    return expiry;
  }

  Future<void> _activate(String productId, DateTime start) async {
    final now = DateTime.now();
    final current = _settingsRepo.read();
    final next = current.copyWith(
      isPro: true,
      subscriptionProductId: productId,
      subscriptionExpiresAtMillis:
          _expiryFrom(productId, start, now).millisecondsSinceEpoch,
    );
    await _settingsRepo.save(next);
  }

  Future<void> _dropExpiredLocalEntitlement() async {
    final current = _settingsRepo.read();
    if (!current.isPro) return;
    final expiry = current.subscriptionExpiresAt;
    if (expiry == null || expiry.isAfter(DateTime.now())) return;
    await _settingsRepo.save(
      current.copyWith(isPro: false, clearSubscription: true),
    );
  }

  AppSettings readSettings() => _settingsRepo.read();

  String remainingLabel([DateTime? now]) =>
      _settingsRepo.read().remainingLabel(now);

  Future<void> dispose() async {
    await _sub?.cancel();
    await _changes.close();
  }
}
