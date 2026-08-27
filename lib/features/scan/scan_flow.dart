import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../reader/reader_screen.dart';

Future<void> startScanFlow(BuildContext context, WidgetRef ref) async {
  final scan = ref.read(scanServiceProvider);
  if (!scan.isSupported) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Document scanning is available on Android. Google\'s scanner is not available on iOS yet.',
        ),
      ),
    );
    return;
  }

  final bool useOcr;
  if (!scan.ocrSupported) {
    useOcr = false;
  } else {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Scan to PDF',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Capture one or more pages. OCR makes the result searchable, but takes a little longer.',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Scan with OCR'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Scan without OCR'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (choice == null || !context.mounted) return;
    useOcr = choice;
  }

  if (!context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                useOcr
                    ? 'Scanning and reading text…'
                    : 'Building your PDF…',
              ),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    final result = await scan.scanToPdf(runOcr: useOcr);
    if (!context.mounted) return;
    Navigator.of(context).pop(); // loading

    if (result == null) return;

    final item = await ref.read(libraryProvider.notifier).importPath(
          result.path,
          name: result.ocrEnabled
              ? 'Scan OCR ${DateTime.now().month}-${DateTime.now().day}.pdf'
              : 'Scan ${DateTime.now().month}-${DateTime.now().day}.pdf',
        );
    if (!context.mounted) return;

    final message = !result.ocrEnabled
        ? 'Saved as an image PDF. Text is not searchable.'
        : result.ocrWordCount == 0
            ? 'No text was recognized. Saved as an image PDF.'
            : 'OCR added ${result.ocrWordCount} words. Use search to find them.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(document: item)),
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Scan failed: $e')),
    );
  }
}
