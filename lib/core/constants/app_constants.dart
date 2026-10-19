class AppConstants {
  AppConstants._();

  static const String appName = 'Folio';
  static const String appTagline = 'Read, mark up, and edit PDFs without the clutter.';

  /// Replace with your Syncfusion Community License key before release.
  static const String syncfusionLicenseKey = '';

  /// AdMob test unit IDs. Swap for production IDs before store release.
  static const String admobAppOpenUnitId = 'ca-app-pub-3940256099942544/9257395921';
  static const String admobBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String admobInterstitialUnitId = 'ca-app-pub-3940256099942544/1033173712';

  /// Play / App Store auto-renewing subscription product IDs.
  /// Create these exact IDs in Play Console and App Store Connect.
  static const String premiumMonthlyId = 'folio_premium_monthly';
  static const String premiumYearlyId = 'folio_premium_yearly';
  static const Set<String> premiumProductIds = {
    premiumMonthlyId,
    premiumYearlyId,
  };
  static const String premiumMonthlyPriceLabel = r'$9.99';
  static const String premiumYearlyPriceLabel = r'$99.99';

  static const String hiveBoxSettings = 'settings';
  static const String hiveBoxLibrary = 'library';
  static const String hiveBoxBookmarks = 'bookmarks';
  static const String hiveBoxFavorites = 'favorites';

  static const List<int> highlightColors = [
    0xFFF2B705, // amber (default)
    0xFFFF6B6B,
    0xFF4ECDC4,
    0xFF95E06C,
    0xFFA78BFA,
  ];
}
