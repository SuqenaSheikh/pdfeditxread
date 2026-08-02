import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/constants/app_constants.dart';
import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';

class PurchaseService {
  PurchaseService(this._settingsRepo);

  final SettingsRepository _settingsRepo;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  final _proController = StreamController<bool>.broadcast();
  Stream<bool> get proStream => _proController.stream;

  bool _available = false;
  ProductDetails? _proProduct;

  bool get isAvailable => _available;
  ProductDetails? get proProduct => _proProduct;

  Future<void> init() async {
    _available = await _iap.isAvailable();
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('IAP stream error: $e'),
    );

    if (_available) {
      final response = await _iap.queryProductDetails(
        {AppConstants.proProductId},
      );
      if (response.productDetails.isNotEmpty) {
        _proProduct = response.productDetails.first;
      }
    }
  }

  Future<bool> buyPro() async {
    // Dev / store-unavailable fallback: unlock Pro locally so the flow
    // can be exercised without a configured product.
    if (!_available || _proProduct == null) {
      await _setPro(true);
      return true;
    }

    final param = PurchaseParam(productDetails: _proProduct!);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() async {
    if (!_available) {
      await _setPro(_settingsRepo.read().isPro);
      return;
    }
    await _iap.restorePurchases();
  }

  /// Debug helper used by Settings when store products are unavailable.
  Future<void> unlockProForTesting() => _setPro(true);

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != AppConstants.proProductId) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _setPro(true);
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('IAP error: ${purchase.error}');
      }
    }
  }

  Future<void> _setPro(bool value) async {
    final current = _settingsRepo.read();
    if (current.isPro == value) {
      _proController.add(value);
      return;
    }
    final next = current.copyWith(isPro: value);
    await _settingsRepo.save(next);
    _proController.add(value);
  }

  AppSettings readSettings() => _settingsRepo.read();

  Future<void> dispose() async {
    await _sub?.cancel();
    await _proController.close();
  }
}
