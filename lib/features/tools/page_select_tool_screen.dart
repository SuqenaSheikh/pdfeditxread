import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../data/models/pdf_document_item.dart';
import 'page_thumb_loader.dart';
import 'pdf_tool_preview_screen.dart';

enum PageSelectMode { split, delete }

class PageSelectToolScreen extends ConsumerStatefulWidget {
  const PageSelectToolScreen({
    super.key,
    required this.document,
    required this.pageCount,
    required this.mode,
  });

  final PdfDocumentItem document;
  final int pageCount;
  final PageSelectMode mode;

  @override
  ConsumerState<PageSelectToolScreen> createState() =>
      _PageSelectToolScreenState();
}

class _PageSelectToolScreenState extends ConsumerState<PageSelectToolScreen> {
  late final PageThumbLoader _loader;
  final Set<int> _selected = {};
  int? _previewPage;

  @override
  void initState() {
    super.initState();
    _loader = createPageThumbLoader(ref);
    _loader.open(widget.document.path);
  }

  @override
  void dispose() {
    _loader.close();
    super.dispose();
  }

  bool get _canSubmit {
    if (_selected.isEmpty) return false;
    if (widget.mode == PageSelectMode.split) {
      return _selected.length < widget.pageCount;
    }
    return _selected.length < widget.pageCount;
  }

  String get _title => switch (widget.mode) {
        PageSelectMode.split => 'Split PDF',
        PageSelectMode.delete => 'Delete pages',
      };

  String get _actionLabel => switch (widget.mode) {
        PageSelectMode.split => 'Split & save',
        PageSelectMode.delete => 'Delete & save',
      };

  String get _hint => switch (widget.mode) {
        PageSelectMode.split =>
          'Selected pages become the first PDF. Unselected pages become the second.',
        PageSelectMode.delete =>
          'Select the pages you want to remove from the document.',
      };

  void _toggle(int page) {
    setState(() {
      if (_selected.contains(page)) {
        _selected.remove(page);
      } else {
        _selected.add(page);
      }
    });
  }

  void _togglePreview(int page) {
    setState(() {
      _previewPage = _previewPage == page ? null : page;
    });
  }

  void _openFullPreview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfToolPreviewScreen(
          path: widget.document.path,
          title: widget.document.name,
        ),
      ),
    );
  }

  void _submit() {
    if (!_canSubmit) return;
    HapticFeedback.selectionClick();
    final pages = _selected.toList()..sort();
    Navigator.pop(context, pages);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedCount = _selected.length;
    final restCount = widget.pageCount - selectedCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Preview PDF',
            onPressed: _openFullPreview,
            icon: const Icon(PhosphorIconsRegular.eye),
          ),
          TextButton(
            onPressed: _canSubmit ? _submit : null,
            child: Text(_actionLabel),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              _hint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              widget.mode == PageSelectMode.split
                  ? '$selectedCount in PDF 1 · $restCount in PDF 2'
                  : '$selectedCount page${selectedCount == 1 ? '' : 's'} selected to delete',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: widget.pageCount,
              itemBuilder: (context, index) {
                final page = index + 1;
                final selected = _selected.contains(page);
                final expanded = _previewPage == page;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selected
                        ? colors.primary.withValues(alpha: 0.06)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _toggle(page),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected || expanded
                                ? colors.primary
                                : colors.outline,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                selected
                                    ? PhosphorIconsFill.checkCircle
                                    : PhosphorIconsRegular.circle,
                                color: selected
                                    ? colors.primary
                                    : colors.outline,
                              ),
                              title: Text('Page $page'),
                              subtitle: widget.mode == PageSelectMode.split
                                  ? Text(
                                      selected
                                          ? 'Goes to PDF 1'
                                          : 'Goes to PDF 2',
                                    )
                                  : Text(
                                      selected
                                          ? 'Will be deleted'
                                          : 'Will be kept',
                                    ),
                              trailing: IconButton(
                                tooltip:
                                    expanded ? 'Hide preview' : 'Preview page',
                                onPressed: () => _togglePreview(page),
                                icon: Icon(
                                  expanded
                                      ? PhosphorIconsFill.eye
                                      : PhosphorIconsRegular.eye,
                                  color: expanded ? colors.primary : null,
                                ),
                              ),
                            ),
                            if (expanded)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: PageThumbImage(
                                  loader: _loader,
                                  pageOneBased: page,
                                  height: 220,
                                ),
                              ),
                          ],
                        ),
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
