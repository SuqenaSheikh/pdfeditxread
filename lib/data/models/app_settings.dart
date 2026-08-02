enum AppThemeMode { system, light, dark }

enum ReaderLayoutMode { continuous, pageByPage }

class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.hasCompletedOnboarding = false,
    this.isPro = false,
    this.readerLayout = ReaderLayoutMode.continuous,
    this.nightModeEnabled = false,
    this.launchCount = 0,
  });

  final AppThemeMode themeMode;
  final bool hasCompletedOnboarding;
  final bool isPro;
  final ReaderLayoutMode readerLayout;
  final bool nightModeEnabled;
  final int launchCount;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? hasCompletedOnboarding,
    bool? isPro,
    ReaderLayoutMode? readerLayout,
    bool? nightModeEnabled,
    int? launchCount,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      isPro: isPro ?? this.isPro,
      readerLayout: readerLayout ?? this.readerLayout,
      nightModeEnabled: nightModeEnabled ?? this.nightModeEnabled,
      launchCount: launchCount ?? this.launchCount,
    );
  }

  Map<String, dynamic> toMap() => {
        'themeMode': themeMode.name,
        'hasCompletedOnboarding': hasCompletedOnboarding,
        'isPro': isPro,
        'readerLayout': readerLayout.name,
        'nightModeEnabled': nightModeEnabled,
        'launchCount': launchCount,
      };

  factory AppSettings.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const AppSettings();
    return AppSettings(
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == map['themeMode'],
        orElse: () => AppThemeMode.system,
      ),
      hasCompletedOnboarding:
          (map['hasCompletedOnboarding'] as bool?) ?? false,
      isPro: (map['isPro'] as bool?) ?? false,
      readerLayout: ReaderLayoutMode.values.firstWhere(
        (e) => e.name == map['readerLayout'],
        orElse: () => ReaderLayoutMode.continuous,
      ),
      nightModeEnabled: (map['nightModeEnabled'] as bool?) ?? false,
      launchCount: (map['launchCount'] as int?) ?? 0,
    );
  }
}
