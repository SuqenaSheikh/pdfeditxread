import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../pro/pro_paywall_screen.dart';
import '../scan/scan_flow.dart';
import 'tool_flows.dart';

class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(settingsProvider).isPro;

    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            'Work on files without opening the reader.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 16),
          if (ref.watch(scanServiceProvider).isSupported)
            _ToolCard(
              icon: PhosphorIconsRegular.scan,
              title: 'Scan to PDF',
              subtitle: 'Camera capture with crop and optional OCR',
              onTap: () => startScanFlow(context, ref),
            ),
          _ToolCard(
            icon: PhosphorIconsRegular.files,
            title: 'Merge PDFs',
            subtitle: 'Combine several files into one document',
            onTap: () => runMergeFlow(context, ref),
          ),
          _ToolCard(
            icon: PhosphorIconsRegular.scissors,
            title: 'Split PDF',
            subtitle: 'Split selected pages into a second file',
            onTap: () => runSplitFlow(context, ref),
          ),
          _ToolCard(
            icon: PhosphorIconsRegular.arrowsDownUp,
            title: 'Reorder pages',
            subtitle: 'Drag pages and preview as you go',
            onTap: () => runReorderFlow(context, ref),
          ),
          _ToolCard(
            icon: PhosphorIconsRegular.image,
            title: 'PDF to images',
            subtitle: 'Save pages as PNG or JPEG in your gallery',
            onTap: () => runExportImagesFlow(context, ref),
          ),
          _ToolCard(
            icon: PhosphorIconsRegular.trash,
            title: 'Delete pages',
            subtitle: isPro ? 'Remove pages and save a new file' : 'Pro',
            badge: isPro ? null : 'Pro',
            onTap: () async {
              final ok = await requirePro(
                context,
                ref,
                featureLabel: 'Delete pages is part of Folio Pro.',
              );
              if (ok && context.mounted) {
                await runDeletePagesFlow(context, ref);
              }
            },
          ),
          _ToolCard(
            icon: PhosphorIconsRegular.lockKey,
            title: 'Password protect',
            subtitle: isPro ? 'Encrypt a PDF with a password' : 'Pro',
            badge: isPro ? null : 'Pro',
            onTap: () async {
              final ok = await requirePro(
                context,
                ref,
                featureLabel: 'Password protection is part of Folio Pro.',
              );
              if (ok && context.mounted) {
                await runPasswordFlow(context, ref);
              }
            },
          ),
          // FR-21 (PDF → Word): deferred — needs a cloud conversion API, not in V1.
          // _ToolCard(
          //   icon: PhosphorIconsRegular.fileDoc,
          //   title: 'Convert to Word',
          //   subtitle: 'Coming soon',
          //   muted: true,
          //   onTap: () {
          //     ScaffoldMessenger.of(context).showSnackBar(
          //       const SnackBar(
          //         content: Text(
          //           'Word conversion is on the roadmap. It needs a cloud service, so it is not in this release.',
          //         ),
          //       ),
          //     );
          //   },
          // ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.muted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: muted
                        ? colors.outline.withValues(alpha: 0.35)
                        : colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: muted ? colors.onSurface.withValues(alpha: 0.45) : colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentSecondary
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  color: colors.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
