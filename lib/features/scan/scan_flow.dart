import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../reader/reader_screen.dart';

Future<void> startScanFlow(BuildContext context, WidgetRef ref) async {
  final scan = ref.read(scanServiceProvider);
  if (!scan.isSupported) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scanning works on Android and iOS devices.'),
      ),
    );
    return;
  }

  final runOcr = await showModalBottomSheet<bool>(
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

  if (runOcr == null || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Building your PDF…'),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    final path = await scan.scanToPdf(runOcr: runOcr);
    if (!context.mounted) return;
    Navigator.of(context).pop(); // loading

    if (path == null) return;

    final item = await ref.read(libraryProvider.notifier).importPath(
          path,
          name: 'Scan ${DateTime.now().month}-${DateTime.now().day}.pdf',
        );
    if (!context.mounted) return;
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
