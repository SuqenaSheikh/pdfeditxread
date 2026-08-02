import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/constants/app_constants.dart';

class AdsService {
  bool _initialized = false;
  bool _isPro = false;
  AppOpenAd? _appOpenAd;
  InterstitialAd? _interstitialAd;
  DateTime? _lastAppOpenShown;
  bool _firstLaunch = true;

  Future<void> init({required bool isPro, required bool firstLaunch}) async {
    _isPro = isPro;
    _firstLaunch = firstLaunch;
    if (_isPro) return;

    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      await _loadAppOpen();
      await _loadInterstitial();
    } catch (e) {
      debugPrint('Ads init failed: $e');
    }
  }

  void setPro(bool isPro) {
    _isPro = isPro;
    if (isPro) {
      _appOpenAd?.dispose();
      _interstitialAd?.dispose();
      _appOpenAd = null;
      _interstitialAd = null;
    }
  }

  bool get showAds => !_isPro && _initialized;

  BannerAd? createLibraryBanner({
    required void Function(Ad) onLoaded,
    void Function(Ad, LoadAdError)? onFailed,
  }) {
    if (!showAds) return null;
    final banner = BannerAd(
      size: AdSize.banner,
      adUnitId: AppConstants.admobBannerUnitId,
      listener: BannerAdListener(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onFailed?.call(ad, error);
        },
      ),
      request: const AdRequest(),
    )..load();
    return banner;
  }

  Future<void> showAppOpenIfAllowed() async {
    if (!showAds || _firstLaunch) return;
    final now = DateTime.now();
    if (_lastAppOpenShown != null &&
        now.difference(_lastAppOpenShown!) < const Duration(minutes: 4)) {
      return;
    }
    final ad = _appOpenAd;
    if (ad == null) {
      await _loadAppOpen();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        _loadAppOpen();
      },
    );
    await ad.show();
    _lastAppOpenShown = now;
    _appOpenAd = null;
  }

  /// Natural breakpoints only: closing a file / returning to library.
  Future<void> showInterstitialAtBreakpoint() async {
    if (!showAds) return;
    final ad = _interstitialAd;
    if (ad == null) {
      await _loadInterstitial();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
    );
    await ad.show();
    _interstitialAd = null;
  }

  Future<void> _loadAppOpen() async {
    if (!showAds) return;
    await AppOpenAd.load(
      adUnitId: AppConstants.admobAppOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpenAd = ad,
        onAdFailedToLoad: (error) =>
            debugPrint('AppOpen load failed: $error'),
      ),
    );
  }

  Future<void> _loadInterstitial() async {
    if (!showAds) return;
    await InterstitialAd.load(
      adUnitId: AppConstants.admobInterstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) =>
            debugPrint('Interstitial load failed: $error'),
      ),
    );
  }

  void markFirstLaunchDone() => _firstLaunch = false;
}
