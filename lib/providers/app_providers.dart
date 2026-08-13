import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../data/models/pdf_document_item.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/ads_service.dart';
import '../data/services/library_service.dart';
import '../data/services/pdf_ops_service.dart';
import '../data/services/purchase_service.dart';
import '../data/services/scan_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError('settingsRepositoryProvider must be overridden');
});

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  throw UnimplementedError('libraryRepositoryProvider must be overridden');
});

final pdfOpsServiceProvider = Provider<PdfOpsService>((ref) => PdfOpsService());

final libraryServiceProvider = Provider<LibraryService>((ref) {
  return LibraryService(
    ref.watch(libraryRepositoryProvider),
    ref.watch(pdfOpsServiceProvider),
  );
});

final scanServiceProvider = Provider<ScanService>((ref) {
  return ScanService(ref.watch(pdfOpsServiceProvider));
});

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  throw UnimplementedError('purchaseServiceProvider must be overridden');
});

final adsServiceProvider = Provider<AdsService>((ref) {
  throw UnimplementedError('adsServiceProvider must be overridden');
});

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(settingsRepositoryProvider));
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._repo) : super(_repo.read());

  final SettingsRepository _repo;

  Future<void> update(AppSettings Function(AppSettings) fn) async {
    final next = fn(state);
    state = next;
    await _repo.save(next);
  }

  Future<void> setThemeMode(AppThemeMode mode) =>
      update((s) => s.copyWith(themeMode: mode));

  Future<void> completeOnboarding() =>
      update((s) => s.copyWith(hasCompletedOnboarding: true));

  Future<void> setPro(bool value) => update((s) => s.copyWith(isPro: value));

  Future<void> setReaderLayout(ReaderLayoutMode mode) =>
      update((s) => s.copyWith(readerLayout: mode));

  Future<void> setNightMode(bool value) =>
      update((s) => s.copyWith(nightModeEnabled: value));

  Future<void> bumpLaunchCount() =>
      update((s) => s.copyWith(launchCount: s.launchCount + 1));
}

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, List<PdfDocumentItem>>((ref) {
  return LibraryNotifier(ref.watch(libraryServiceProvider));
});

class LibraryNotifier extends StateNotifier<List<PdfDocumentItem>> {
  LibraryNotifier(this._service) : super(_service.all());

  final LibraryService _service;

  void refresh() => state = _service.all();

  Future<PdfDocumentItem?> importFile() async {
    final item = await _service.pickAndImport();
    refresh();
    return item;
  }

  Future<void> openTracked(PdfDocumentItem item, {int? page}) async {
    await _service.markOpened(item, page: page);
    refresh();
  }

  Future<void> toggleFavorite(PdfDocumentItem item) async {
    await _service.toggleFavorite(item);
    refresh();
  }

  Future<void> remove(PdfDocumentItem item) async {
    await _service.remove(item);
    refresh();
  }

  Future<void> rename(PdfDocumentItem item, String name) async {
    await _service.rename(item, name);
    refresh();
  }

  Future<PdfDocumentItem> importPath(String path, {String? name}) async {
    final item = await _service.importFromPath(path, displayName: name);
    refresh();
    return item;
  }
}

final recentDocumentsProvider = Provider<List<PdfDocumentItem>>((ref) {
  final all = ref.watch(libraryProvider);
  final sorted = [...all.where((e) => e.lastOpenedAt != null)]
    ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
  return sorted;
});

final favoriteDocumentsProvider = Provider<List<PdfDocumentItem>>((ref) {
  return ref.watch(libraryProvider).where((e) => e.isFavorite).toList();
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  switch (ref.watch(settingsProvider).themeMode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
});

/// Session-only skip of onboarding (does not persist). Cleared on process restart.
final onboardingSkippedThisSessionProvider = StateProvider<bool>((ref) => false);
