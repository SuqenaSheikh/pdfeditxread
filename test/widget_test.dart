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
    );
    final restored = AppSettings.fromMap(original.toMap());
    expect(restored.themeMode, AppThemeMode.dark);
    expect(restored.isPro, isTrue);
    expect(restored.readerLayout, ReaderLayoutMode.pageByPage);
    expect(AppConstants.appName, 'Folio');
  });
}
