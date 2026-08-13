import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../data/models/pdf_document_item.dart';
import 'page_thumb_loader.dart';

class ReorderPagesScreen extends ConsumerStatefulWidget {
  const ReorderPagesScreen({
    super.key,
    required this.document,
    required this.pageCount,
  });

  final PdfDocumentItem document;
  final int pageCount;

  @override
  ConsumerState<ReorderPagesScreen> createState() => _ReorderPagesScreenState();
}

class _ReorderPagesScreenState extends ConsumerState<ReorderPagesScreen> {
  late List<int> _order;
  late final PageThumbLoader _loader;
  int? _previewPage;

  @override
  void initState() {
    super.initState();
    _order = List<int>.generate(widget.pageCount, (i) => i + 1);
    _loader = createPageThumbLoader(ref);
    _loader.open(widget.document.path);
  }

  @override
  void dispose() {
    _loader.close();
    super.dispose();
  }

  void _togglePreview(int page) {
    setState(() {
      _previewPage = _previewPage == page ? null : page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder pages'),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context, _order);
            },
            child: const Text('Done'),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _order.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _order.removeAt(oldIndex);
            _order.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final page = _order[index];
          final expanded = _previewPage == page;
          return Material(
            key: ValueKey('page-$page'),
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: expanded ? colors.primary : colors.outline,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          colors.primary.withValues(alpha: 0.12),
                      foregroundColor: colors.primary,
                      child: Text('$page'),
                    ),
                    title: Text('Page $page'),
                    subtitle: Text('Position ${index + 1}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: expanded ? 'Hide preview' : 'Preview',
                          onPressed: () => _togglePreview(page),
                          icon: Icon(
                            expanded
                                ? PhosphorIconsFill.eye
                                : PhosphorIconsRegular.eye,
                            color: expanded ? colors.primary : null,
                          ),
                        ),
                        const Icon(Icons.drag_handle),
                      ],
                    ),
                  ),
                  if (expanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: PageThumbImage(
                        loader: _loader,
                        pageOneBased: page,
                        height: 220,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
