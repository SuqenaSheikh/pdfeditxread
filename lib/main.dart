import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/repositories/library_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/ads_service.dart';
import 'data/services/purchase_service.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Hive.initFlutter();
  final settingsRepo = await SettingsRepository.open();
  final libraryRepo = await LibraryRepository.open();

  final purchaseService = PurchaseService(settingsRepo);
  await purchaseService.init();

  var settings = settingsRepo.read();
  settings = settings.copyWith(launchCount: settings.launchCount + 1);
  await settingsRepo.save(settings);

  final adsService = AdsService();
  await adsService.init(
    isPro: settings.isPro,
    firstLaunch: settings.launchCount <= 1,
  );
  if (settings.launchCount > 1) {
    // ignore: unawaited_futures
    adsService.showAppOpenIfAllowed();
  }
  adsService.markFirstLaunchDone();

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        libraryRepositoryProvider.overrideWithValue(libraryRepo),
        purchaseServiceProvider.overrideWithValue(purchaseService),
        adsServiceProvider.overrideWithValue(adsService),
      ],
      child: const FolioApp(),
    ),
  );
}
