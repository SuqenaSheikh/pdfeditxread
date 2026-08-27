import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/models/pdf_document_item.dart';

Future<void> showReaderBookmarksSheet({
  required BuildContext context,
  required List<PageBookmark> bookmarks,
  required ValueChanged<int> onJumpToPage,
  required VoidCallback onOpenOutline,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Bookmarks',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
            ),
            if (bookmarks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No page bookmarks yet for this file.'),
              )
            else
              ...bookmarks.map(
                (b) => ListTile(
                  leading: const Icon(PhosphorIconsRegular.bookmarkSimple),
                  title: Text('Page ${b.pageNumber}'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onJumpToPage(b.pageNumber);
                  },
                ),
              ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.listBullets),
              title: const Text('Document outline'),
              onTap: () {
                Navigator.pop(ctx);
                onOpenOutline();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
