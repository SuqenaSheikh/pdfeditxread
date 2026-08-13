import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/widgets/document_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/pdf_document_item.dart';
import '../../providers/app_providers.dart';

/// Library-style picker used by merge / split / reorder / delete tools.
class ToolPdfPickerScreen extends ConsumerStatefulWidget {
  const ToolPdfPickerScreen({
    super.key,
    required this.title,
    this.allowMultiple = false,
    this.minSelection = 1,
    this.continueLabel = 'Continue',
  });

  final String title;
  final bool allowMultiple;
  final int minSelection;
  final String continueLabel;

  @override
  ConsumerState<ToolPdfPickerScreen> createState() =>
      _ToolPdfPickerScreenState();
}

class _ToolPdfPickerScreenState extends ConsumerState<ToolPdfPickerScreen> {
  String _query = '';
  final Set<String> _selectedIds = {};

  List<PdfDocumentItem> get _filtered {
    final docs = ref.watch(libraryProvider);
    if (_query.isEmpty) return docs;
    final q = _query.toLowerCase();
    return docs.where((d) => d.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _import() async {
    await ref.read(libraryProvider.notifier).importFile();
  }

  void _toggle(PdfDocumentItem doc) {
    if (widget.allowMultiple) {
      setState(() {
        if (_selectedIds.contains(doc.id)) {
          _selectedIds.remove(doc.id);
        } else {
          _selectedIds.add(doc.id);
        }
      });
      return;
    }
    Navigator.of(context).pop(<PdfDocumentItem>[doc]);
  }

  void _continue() {
    final docs = ref.read(libraryProvider);
    final selected = docs.where((d) => _selectedIds.contains(d.id)).toList();
    if (selected.length < widget.minSelection) return;
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(libraryProvider);
    final filtered = _filtered;
    final canContinue =
        widget.allowMultiple && _selectedIds.length >= widget.minSelection;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.allowMultiple)
            TextButton(
              onPressed: canContinue ? _continue : null,
              child: Text(widget.continueLabel),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _import,
        icon: const Icon(PhosphorIconsRegular.plus),
        label: const Text('Add PDF'),
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
          if (widget.allowMultiple)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _selectedIds.isEmpty
                      ? 'Select at least ${widget.minSelection} PDFs'
                      : '${_selectedIds.length} selected',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    message: docs.isEmpty
                        ? 'Your library is empty. Add a PDF to continue.'
                        : 'Nothing matches that search.',
                    actionLabel: docs.isEmpty ? 'Add PDF' : 'Clear search',
                    onAction: docs.isEmpty
                        ? _import
                        : () => setState(() => _query = ''),
                    icon: PhosphorIconsRegular.folderOpen,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final selected = widget.allowMultiple
                          ? _selectedIds.contains(doc.id)
                          : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DocumentTile(
                          document: doc,
                          selected: selected,
                          onTap: () => _toggle(doc),
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
