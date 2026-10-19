import '../../core/constants/app_constants.dart';

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
    this.subscriptionProductId,
    this.subscriptionExpiresAtMillis,
  });

  final AppThemeMode themeMode;
  final bool hasCompletedOnboarding;
  final bool isPro;
  final ReaderLayoutMode readerLayout;
  final bool nightModeEnabled;
  final int launchCount;
  final String? subscriptionProductId;
  final int? subscriptionExpiresAtMillis;

  DateTime? get subscriptionExpiresAt => subscriptionExpiresAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(subscriptionExpiresAtMillis!);

  bool get isMonthlyPro =>
      isPro && subscriptionProductId == AppConstants.premiumMonthlyId;

  bool get isYearlyPro =>
      isPro && subscriptionProductId == AppConstants.premiumYearlyId;

  String get planLabel {
    if (isYearlyPro) return 'Yearly';
    if (isMonthlyPro) return 'Monthly';
    return 'Pro';
  }

  String remainingLabel([DateTime? now]) {
    if (!isPro) return '';
    final expiry = subscriptionExpiresAt;
    if (expiry == null) return 'Active';
    final left = expiry.difference(now ?? DateTime.now());
    if (left.isNegative) return 'Expired — renew to keep Pro';
    if (left.inDays >= 1) {
      final days = left.inDays;
      return '$days day${days == 1 ? '' : 's'} left';
    }
    if (left.inHours >= 1) {
      return '${left.inHours} hour${left.inHours == 1 ? '' : 's'} left';
    }
    return 'Less than an hour left';
  }

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? hasCompletedOnboarding,
    bool? isPro,
    ReaderLayoutMode? readerLayout,
    bool? nightModeEnabled,
    int? launchCount,
    String? subscriptionProductId,
    int? subscriptionExpiresAtMillis,
    bool clearSubscription = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      isPro: isPro ?? this.isPro,
      readerLayout: readerLayout ?? this.readerLayout,
      nightModeEnabled: nightModeEnabled ?? this.nightModeEnabled,
      launchCount: launchCount ?? this.launchCount,
      subscriptionProductId: clearSubscription
          ? null
          : (subscriptionProductId ?? this.subscriptionProductId),
      subscriptionExpiresAtMillis: clearSubscription
          ? null
          : (subscriptionExpiresAtMillis ?? this.subscriptionExpiresAtMillis),
    );
  }

  Map<String, dynamic> toMap() => {
        'themeMode': themeMode.name,
        'hasCompletedOnboarding': hasCompletedOnboarding,
        'isPro': isPro,
        'readerLayout': readerLayout.name,
        'nightModeEnabled': nightModeEnabled,
        'launchCount': launchCount,
        'subscriptionProductId': subscriptionProductId,
        'subscriptionExpiresAtMillis': subscriptionExpiresAtMillis,
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
      subscriptionProductId: map['subscriptionProductId'] as String?,
      subscriptionExpiresAtMillis: (map['subscriptionExpiresAtMillis'] as num?)
          ?.toInt(),
    );
  }
}
