import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/widgets/document_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/pdf_document_item.dart';
import '../../providers/app_providers.dart';
import '../reader/reader_screen.dart';

class RecentScreen extends ConsumerWidget {
  const RecentScreen({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    PdfDocumentItem doc,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!context.mounted) return;
    await ref.read(libraryProvider.notifier).openTracked(doc);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(document: doc)),
    );
    if (!context.mounted) return;
    ref.read(libraryProvider.notifier).refresh();
    // TODO(ads): re-enable interstitial after reader close.
    // await ref.read(adsServiceProvider).showInterstitialAtBreakpoint();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentDocumentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recent')),
      body: recents.isEmpty
          ? EmptyState(
              message:
                  'Files you open will show up here, sorted by the last time you read them.',
              actionLabel: 'Go to library',
              onAction: () {
                // Parent shell owns tabs; nudge via snackbar.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Open a PDF from the Library tab.'),
                  ),
                );
              },
              icon: PhosphorIconsRegular.clock,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: recents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = recents[index];
                return DocumentTile(
                  document: doc,
                  onTap: () => _open(context, ref, doc),
                  onFavorite: () =>
                      ref.read(libraryProvider.notifier).toggleFavorite(doc),
                  onShare: () =>
                      ref.read(libraryServiceProvider).share(doc),
                  onDelete: () =>
                      ref.read(libraryProvider.notifier).remove(doc),
                );
              },
            ),
    );
  }
}
