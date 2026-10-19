import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_constants.dart';
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
  StreamSubscription<void>? _iapSub;

  @override
  void initState() {
    super.initState();
    _iapSub = ref.read(purchaseServiceProvider).changes.listen((_) {
      if (!mounted) return;
      ref.read(settingsProvider.notifier).reload();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _iapSub?.cancel();
    super.dispose();
  }

  Future<void> _syncAfterPurchase() async {
    await ref.read(settingsProvider.notifier).reload();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _buyMonthly() async {
    setState(() => _busy = true);
    try {
      await ref.read(purchaseServiceProvider).buyMonthly();
      await _syncAfterPurchase();
      if (!mounted) return;
      if (ref.read(settingsProvider).isPro) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monthly Pro is active.')),
        );
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

  Future<void> _buyYearly({required bool isUpgrade}) async {
    setState(() => _busy = true);
    try {
      await ref.read(purchaseServiceProvider).buyYearly();
      await _syncAfterPurchase();
      if (!mounted) return;
      if (ref.read(settingsProvider).isYearlyPro) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUpgrade
                  ? 'Upgraded to yearly. Unused monthly time is credited.'
                  : 'Yearly Pro is active.',
            ),
          ),
        );
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
      await _syncAfterPurchase();
      if (!mounted) return;
      final isPro = ref.read(settingsProvider).isPro;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPro
                ? 'Welcome back. Pro is active again.'
                : 'No Pro subscription found on this account.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    try {
      await ref.read(purchaseServiceProvider).openManageSubscriptions();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Open your store account to cancel. Subscriptions can only be cancelled in Play Store or App Store.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchases = ref.watch(purchaseServiceProvider);
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final expiry = settings.subscriptionExpiresAt;
    final remaining = settings.remainingLabel();

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
                  settings.isPro
                      ? 'Your Pro subscription'
                      : 'Unlock Folio Pro',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 22,
                      ),
                ),
                const SizedBox(height: 8),
                if (settings.isPro) ...[
                  Text(
                    remaining.isEmpty ? 'Active' : remaining,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.primary,
                        ),
                  ),
                  if (expiry != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${settings.planLabel} plan · ${expiry.isBefore(DateTime.now()) ? 'ended' : 'renews'} ${DateFormat.yMMMd().format(expiry)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.75),
                          ),
                    ),
                  ],
                ] else
                  Text(
                    widget.highlightFeature ??
                        'TTS, add text, delete pages, and password lock.',
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
            title: 'Add text to PDFs',
            subtitle: 'Place new text on a page and save it into the file.',
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
          const SizedBox(height: 16),
          if (!settings.isPro) ...[
            _PlanButton(
              title: 'Monthly',
              price: purchases.monthlyPriceLabel,
              subtitle: 'Billed every month',
              enabled: !_busy,
              onPressed: _buyMonthly,
            ),
            const SizedBox(height: 10),
            _PlanButton(
              title: 'Yearly',
              price: purchases.yearlyPriceLabel,
              subtitle: 'Best value · billed once a year',
              highlighted: true,
              enabled: !_busy,
              onPressed: () => _buyYearly(isUpgrade: false),
            ),
          ] else ...[
            if (settings.isMonthlyPro) ...[
              Text(
                'Switch to yearly and unused monthly time is credited against ${AppConstants.premiumYearlyPriceLabel}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              _PlanButton(
                title: 'Upgrade to yearly',
                price: purchases.yearlyPriceLabel,
                subtitle: 'Pay the difference after your unused monthly credit',
                highlighted: true,
                enabled: !_busy,
                onPressed: () => _buyYearly(isUpgrade: true),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton(
              onPressed: _busy ? null : _cancel,
              child: const Text('Cancel subscription'),
            ),
          ],
          const SizedBox(height: 10),
          TextButton(
            onPressed: _busy ? null : _restore,
            child: const Text('Restore subscription'),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Prices are set in Play Console and App Store Connect. Cancel anytime in your store account. Upgrading monthly to yearly applies unused monthly credit so you are not charged the full yearly price twice.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PlanButton extends StatelessWidget {
  const _PlanButton({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.onPressed,
    required this.enabled,
    this.highlighted = false,
  });

  final String title;
  final String price;
  final String subtitle;
  final VoidCallback onPressed;
  final bool enabled;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Text('$title · $price'),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
    if (highlighted) {
      return ElevatedButton(onPressed: enabled ? onPressed : null, child: child);
    }
    return OutlinedButton(onPressed: enabled ? onPressed : null, child: child);
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
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ProPaywallScreen(
        highlightFeature: featureLabel,
      ),
    ),
  );
  return ref.read(settingsProvider).isPro;
}
