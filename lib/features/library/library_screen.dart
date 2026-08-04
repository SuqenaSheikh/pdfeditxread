import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/ad_banner_slot.dart';
import '../../core/widgets/document_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/pdf_document_item.dart';
import '../../providers/app_providers.dart';
import '../reader/reader_screen.dart';
import '../scan/scan_flow.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _query = '';

  Future<void> _open(PdfDocumentItem doc) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    await ref.read(libraryProvider.notifier).openTracked(doc);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(document: doc)),
    );
    if (!mounted) return;
    ref.read(libraryProvider.notifier).refresh();
    // TODO(ads): re-enable interstitial after reader close.
    // await ref.read(adsServiceProvider).showInterstitialAtBreakpoint();
  }

  Future<void> _import() async {
    final item = await ref.read(libraryProvider.notifier).importFile();
    if (item != null && mounted) await _open(item);
  }

  Future<void> _rename(PdfDocumentItem doc) async {
    final controller = TextEditingController(
      text: doc.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
    );
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'File name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(libraryProvider.notifier).rename(doc, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(libraryProvider);
    final favorites = ref.watch(favoriteDocumentsProvider);
    final filtered = _query.isEmpty
        ? docs
        : docs
            .where((d) => d.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Scan document',
            onPressed: () => startScanFlow(context, ref),
            icon: const Icon(PhosphorIconsRegular.scan),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _import,
        icon: const Icon(PhosphorIconsRegular.plus),
        label: const Text('Open PDF'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search your library',
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(() => _query = ''),
                        icon: const Icon(PhosphorIconsRegular.x),
                      ),
              ),
            ),
          ),
          const AdBannerSlot(), // TODO(ads): temporarily inactive until AdsService.init is re-enabled
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    message: docs.isEmpty
                        ? 'Your library is empty. Open a PDF from your device to get started.'
                        : 'Nothing matches that search.',
                    actionLabel: docs.isEmpty ? 'Open PDF' : 'Clear search',
                    onAction: docs.isEmpty
                        ? _import
                        : () => setState(() => _query = ''),
                    icon: PhosphorIconsRegular.folderOpen,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    children: [
                      if (favorites.isNotEmpty && _query.isEmpty) ...[
                        Text(
                          'Favorites',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        ...favorites.map(
                          (doc) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DocumentTile(
                              document: doc,
                              compact: true,
                              onTap: () => _open(doc),
                              onFavorite: () => ref
                                  .read(libraryProvider.notifier)
                                  .toggleFavorite(doc),
                              onShare: () => ref
                                  .read(libraryServiceProvider)
                                  .share(doc),
                              onDelete: () => ref
                                  .read(libraryProvider.notifier)
                                  .remove(doc),
                              onRename: () => _rename(doc),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'All files',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                      ],
                      ...filtered.map(
                        (doc) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DocumentTile(
                            document: doc,
                            onTap: () => _open(doc),
                            onFavorite: () => ref
                                .read(libraryProvider.notifier)
                                .toggleFavorite(doc),
                            onShare: () =>
                                ref.read(libraryServiceProvider).share(doc),
                            onDelete: () => ref
                                .read(libraryProvider.notifier)
                                .remove(doc),
                            onRename: () => _rename(doc),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
