import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/shell/open_intent_listener.dart';
import 'providers/app_providers.dart';

class FolioApp extends ConsumerStatefulWidget {
  const FolioApp({super.key});

  @override
  ConsumerState<FolioApp> createState() => _FolioAppState();
}

class _FolioAppState extends ConsumerState<FolioApp> {
  StreamSubscription<void>? _iapSub;

  @override
  void initState() {
    super.initState();
    _iapSub = ref.read(purchaseServiceProvider).changes.listen((_) {
      ref.read(settingsProvider.notifier).reload();
    });
  }

  @override
  void dispose() {
    _iapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final onboarded = ref.watch(settingsProvider).hasCompletedOnboarding;
    final skippedThisSession = ref.watch(onboardingSkippedThisSessionProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: (onboarded || skippedThisSession)
          ? const OpenIntentListener(child: HomeShell())
          : const OnboardingScreen(),
    );
  }
}
