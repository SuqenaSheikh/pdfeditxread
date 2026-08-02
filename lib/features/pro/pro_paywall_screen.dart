import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';

class ProPaywallScreen extends ConsumerStatefulWidget {
  const ProPaywallScreen({super.key, this.highlightFeature});

  final String? highlightFeature;

  @override
  ConsumerState<ProPaywallScreen> createState() => _ProPaywallScreenState();
}

class _ProPaywallScreenState extends ConsumerState<ProPaywallScreen> {
  bool _busy = false;

  Future<void> _buy() async {
    setState(() => _busy = true);
    try {
      final ok = await ref.read(purchaseServiceProvider).buyPro();
      if (!mounted) return;
      if (ok || ref.read(settingsProvider).isPro) {
        await ref.read(settingsProvider.notifier).setPro(true);
        ref.read(adsServiceProvider).setPro(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pro is unlocked. Enjoy the quiet.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase could not finish: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      await ref.read(purchaseServiceProvider).restore();
      final isPro = ref.read(settingsProvider).isPro ||
          ref.read(purchaseServiceProvider).readSettings().isPro;
      if (isPro) {
        await ref.read(settingsProvider.notifier).setPro(true);
        ref.read(adsServiceProvider).setPro(true);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPro
                ? 'Welcome back. Pro is active again.'
                : 'No prior Pro purchase found on this account.',
          ),
        ),
      );
      if (isPro) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(purchaseServiceProvider).proProduct;
    final price = product?.price ?? 'one-time unlock';
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Folio Pro')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'One purchase. Ads gone. Real edits unlocked.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 22,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.highlightFeature ??
                      'Pro covers the heavier tools and clears every ad placement.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.75),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _Perk(
            icon: PhosphorIconsRegular.speakerHigh,
            title: 'Text to speech',
            subtitle: 'Listen through a page with play, pause, and skip.',
          ),
          const _Perk(
            icon: PhosphorIconsRegular.cursorText,
            title: 'In-place text editing',
            subtitle: 'Fix a name, date, or figure and save it into the PDF.',
          ),
          const _Perk(
            icon: PhosphorIconsRegular.trash,
            title: 'Delete pages',
            subtitle: 'Trim pages you do not need before sharing.',
          ),
          const _Perk(
            icon: PhosphorIconsRegular.lockKey,
            title: 'Password protection',
            subtitle: 'Encrypt a file with a password you choose.',
          ),
          const _Perk(
            icon: PhosphorIconsRegular.prohibit,
            title: 'No ads',
            subtitle: 'Banners, interstitials, and app-open ads stay off.',
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _busy ? null : _buy,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Unlock Pro · $price'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _busy ? null : _restore,
            child: const Text('Restore purchase'),
          ),
          const SizedBox(height: 8),
          Text(
            'Pricing model may be one-time or subscription depending on store configuration.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentSecondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> requirePro(
  BuildContext context,
  WidgetRef ref, {
  required String featureLabel,
}) async {
  if (ref.read(settingsProvider).isPro) return true;
  final unlocked = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ProPaywallScreen(
        highlightFeature: featureLabel,
      ),
    ),
  );
  return unlocked == true || ref.read(settingsProvider).isPro;
}
