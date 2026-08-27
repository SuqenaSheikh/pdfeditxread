import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ExportImagesResultSheet extends StatelessWidget {
  const ExportImagesResultSheet({
    super.key,
    required this.paths,
    required this.savedToGallery,
  });

  final List<String> paths;
  final bool savedToGallery;

  @override
  Widget build(BuildContext context) {
    final preview = paths.take(6).toList();
    final extra = paths.length - preview.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              savedToGallery
                  ? 'Saved ${paths.length} image${paths.length == 1 ? '' : 's'} to your gallery'
                  : 'Exported ${paths.length} image${paths.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              savedToGallery
                  ? 'Look in Photos / Gallery, album Folio.'
                  : 'They could not be added to the gallery. Share them to save to Files or Photos.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final path in preview)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(path),
                      width: 72,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const SizedBox(
                        width: 72,
                        height: 96,
                        child: Icon(PhosphorIconsRegular.image),
                      ),
                    ),
                  ),
                if (extra > 0)
                  Container(
                    width: 72,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('+$extra'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!savedToGallery)
              OutlinedButton.icon(
                onPressed: () {
                  Share.shareXFiles(
                    [
                      for (final path in paths)
                        XFile(
                          path,
                          mimeType: path.toLowerCase().endsWith('.png')
                              ? 'image/png'
                              : 'image/jpeg',
                          name: path.split(Platform.pathSeparator).last,
                        ),
                    ],
                  );
                },
                icon: const Icon(PhosphorIconsRegular.shareNetwork),
                label: const Text('Share images'),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
