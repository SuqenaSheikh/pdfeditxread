import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_editor/core/constants/app_constants.dart';
import 'package:pdf_editor/data/models/app_settings.dart';

void main() {
  test('App settings round-trip through map', () {
    const original = AppSettings(
      themeMode: AppThemeMode.dark,
      hasCompletedOnboarding: true,
      isPro: true,
      readerLayout: ReaderLayoutMode.pageByPage,
      nightModeEnabled: true,
      launchCount: 3,
      subscriptionProductId: AppConstants.premiumMonthlyId,
      subscriptionExpiresAtMillis: 1700000000000,
    );
    final restored = AppSettings.fromMap(original.toMap());
    expect(restored.themeMode, AppThemeMode.dark);
    expect(restored.isPro, isTrue);
    expect(restored.readerLayout, ReaderLayoutMode.pageByPage);
    expect(restored.isMonthlyPro, isTrue);
    expect(restored.subscriptionProductId, AppConstants.premiumMonthlyId);
    expect(AppConstants.appName, 'Folio');
    expect(AppConstants.premiumMonthlyId, 'folio_premium_monthly');
    expect(AppConstants.premiumYearlyId, 'folio_premium_yearly');
  });

  test('remainingLabel reports days left', () {
    final expiry = DateTime.now().add(const Duration(days: 18, hours: 2));
    final settings = AppSettings(
      isPro: true,
      subscriptionProductId: AppConstants.premiumMonthlyId,
      subscriptionExpiresAtMillis: expiry.millisecondsSinceEpoch,
    );
    expect(settings.remainingLabel(), '18 days left');
    expect(settings.planLabel, 'Monthly');
  });
}
