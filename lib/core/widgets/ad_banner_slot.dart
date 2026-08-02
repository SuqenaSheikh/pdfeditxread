import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../providers/app_providers.dart';

/// Banner slot with a visible "Ad" label. Never placed inline in file lists
/// as a fake document row.
class AdBannerSlot extends ConsumerStatefulWidget {
  const AdBannerSlot({super.key});

  @override
  ConsumerState<AdBannerSlot> createState() => _AdBannerSlotState();
}

class _AdBannerSlotState extends ConsumerState<AdBannerSlot> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final settings = ref.read(settingsProvider);
    if (settings.isPro) return;
    final ads = ref.read(adsServiceProvider);
    final banner = ads.createLibraryBanner(
      onLoaded: (_) {
        if (mounted) setState(() => _loaded = true);
      },
      onFailed: (ad, error) {
        if (mounted) setState(() => _loaded = false);
      },
    );
    setState(() => _banner = banner);
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(settingsProvider).isPro;
    if (isPro || _banner == null || !_loaded) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colors.outline.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Ad',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: _banner!.size.width.toDouble(),
            height: _banner!.size.height.toDouble(),
            child: AdWidget(ad: _banner!),
          ),
        ],
      ),
    );
  }
}
