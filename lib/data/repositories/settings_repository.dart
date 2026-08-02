import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  SettingsRepository(this._box);

  final Box _box;

  static Future<SettingsRepository> open() async {
    final box = await Hive.openBox(AppConstants.hiveBoxSettings);
    return SettingsRepository(box);
  }

  AppSettings read() {
    final raw = _box.get('settings');
    if (raw is Map) return AppSettings.fromMap(raw);
    return const AppSettings();
  }

  Future<void> save(AppSettings settings) async {
    await _box.put('settings', settings.toMap());
  }
}
