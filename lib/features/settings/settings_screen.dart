import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/app_settings.dart';
import '../../providers/app_providers.dart';
import '../pro/pro_paywall_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Group(
            title: 'Appearance',
            child: Column(
              children: [
                _ThemeChoice(
                  mode: settings.themeMode,
                  onChanged: (m) =>
                      ref.read(settingsProvider.notifier).setThemeMode(m),
                ),
                // Night mode inverts every color (blue → yellow, etc.).
                // SwitchListTile(
                //   contentPadding: EdgeInsets.zero,
                //   title: const Text('Night mode for PDFs'),
                //   subtitle: const Text(
                //     'Inverts page colors in the reader. App theme stays independent.',
                //   ),
                //   value: settings.nightModeEnabled,
                //   onChanged: (v) =>
                //       ref.read(settingsProvider.notifier).setNightMode(v),
                // ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Group(
            title: 'Reading',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Default layout'),
                  subtitle: Text(
                    settings.readerLayout == ReaderLayoutMode.continuous
                        ? 'Continuous scroll'
                        : 'Page by page',
                  ),
                  trailing: SegmentedButton<ReaderLayoutMode>(
                    segments: const [
                      ButtonSegment(
                        value: ReaderLayoutMode.continuous,
                        label: Text('Scroll'),
                      ),
                      ButtonSegment(
                        value: ReaderLayoutMode.pageByPage,
                        label: Text('Pages'),
                      ),
                    ],
                    selected: {settings.readerLayout},
                    onSelectionChanged: (s) => ref
                        .read(settingsProvider.notifier)
                        .setReaderLayout(s.first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Group(
            title: 'Folio Pro',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    settings.isPro
                        ? PhosphorIconsFill.crownSimple
                        : PhosphorIconsRegular.crownSimple,
                    color: colors.primary,
                  ),
                  title: Text(settings.isPro ? 'Pro is active' : 'Upgrade to Pro'),
                  subtitle: Text(
                    settings.isPro
                        ? 'Ads are off. TTS, add text, delete, and lock are yours.'
                        : 'Unlock Pro features and remove every ad.',
                  ),
                  trailing: settings.isPro
                      ? null
                      : const Icon(PhosphorIconsRegular.caretRight),
                  onTap: settings.isPro
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProPaywallScreen(),
                            ),
                          ),
                ),
                if (!settings.isPro)
                  TextButton(
                    onPressed: () async {
                      await ref.read(purchaseServiceProvider).restore();
                      final pro = ref
                          .read(purchaseServiceProvider)
                          .readSettings()
                          .isPro;
                      if (pro) {
                        await ref.read(settingsProvider.notifier).setPro(true);
                        ref.read(adsServiceProvider).setPro(true);
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              pro
                                  ? 'Pro restored.'
                                  : 'No purchase found to restore.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Restore purchases'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Group(
            title: 'About',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(AppConstants.appName),
                  subtitle: Text(AppConstants.appTagline),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Version'),
                  subtitle: Text('1.0.0'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({required this.mode, required this.onChanged});

  final AppThemeMode mode;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text('Theme', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        SegmentedButton<AppThemeMode>(
          segments: const [
            ButtonSegment(
              value: AppThemeMode.system,
              label: Text('System'),
              icon: Icon(PhosphorIconsRegular.deviceMobileSpeaker, size: 16),
            ),
            ButtonSegment(
              value: AppThemeMode.light,
              label: Text('Light'),
              icon: Icon(PhosphorIconsRegular.sun, size: 16),
            ),
            ButtonSegment(
              value: AppThemeMode.dark,
              label: Text('Dark'),
              icon: Icon(PhosphorIconsRegular.moon, size: 16),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
