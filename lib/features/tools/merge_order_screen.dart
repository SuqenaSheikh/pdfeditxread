import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/pdf_document_item.dart';
import 'pdf_tool_preview_screen.dart';

class MergeOrderScreen extends StatefulWidget {
  const MergeOrderScreen({super.key, required this.documents});

  final List<PdfDocumentItem> documents;

  @override
  State<MergeOrderScreen> createState() => _MergeOrderScreenState();
}

class _MergeOrderScreenState extends State<MergeOrderScreen> {
  late List<PdfDocumentItem> _order;

  @override
  void initState() {
    super.initState();
    _order = [...widget.documents];
  }

  void _preview(PdfDocumentItem doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfToolPreviewScreen(
          path: doc.path,
          title: doc.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge PDFs'),
        actions: [
          TextButton(
            onPressed: _order.length < 2
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context, _order);
                  },
            child: const Text('Merge'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Drag to set merge order. The top file becomes the start of the merged PDF.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _order.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _order.removeAt(oldIndex);
                  _order.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final doc = _order[index];
                final meta = [
                  if (doc.pageCount != null) formatPageCount(doc.pageCount),
                  if (doc.fileSizeBytes != null)
                    formatFileSize(doc.fileSizeBytes),
                ].where((e) => e.isNotEmpty).join(' · ');

                return Material(
                  key: ValueKey(doc.id),
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.outline),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor:
                            colors.primary.withValues(alpha: 0.12),
                        foregroundColor: colors.primary,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(
                        doc.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: meta.isEmpty ? null : Text(meta),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Preview',
                            onPressed: () => _preview(doc),
                            icon: const Icon(PhosphorIconsRegular.eye),
                          ),
                          const Icon(Icons.drag_handle),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
