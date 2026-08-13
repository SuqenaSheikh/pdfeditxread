import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/shell/open_intent_listener.dart';
import 'providers/app_providers.dart';

class FolioApp extends ConsumerWidget {
  const FolioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
