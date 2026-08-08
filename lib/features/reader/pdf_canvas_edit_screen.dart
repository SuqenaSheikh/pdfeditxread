import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/pdf_document_item.dart';
import '../../data/services/pdf_ops_service.dart';
import '../../providers/app_providers.dart';
import 'editable_text_box.dart';

/// Canva-style PDF text editor: page images + move/resize/edit text boxes.
/// Changes are kept in memory until the user taps Save.
class PdfCanvasEditScreen extends ConsumerStatefulWidget {
  const PdfCanvasEditScreen({
    super.key,
    required this.document,
    this.initialPageIndex = 0,
  });

  final PdfDocumentItem document;
  final int initialPageIndex;

  @override
  ConsumerState<PdfCanvasEditScreen> createState() =>
      _PdfCanvasEditScreenState();
}

class _PdfCanvasEditScreenState extends ConsumerState<PdfCanvasEditScreen> {
  final _uuid = const Uuid();
  final _scrollController = ScrollController();

  List<PdfEditableBox> _boxes = [];
  List<PdfPageMetrics> _pages = [];
  PdfPageRenderSession? _session;
  final Map<int, ui.Image?> _pageImages = {};
  final Set<int> _loadingPages = {};

  String? _selectedId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _hasUnsaved => _boxes.any((b) => b.needsSave);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final img in _pageImages.values) {
      img?.dispose();
    }
    _session?.close();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ops = ref.read(pdfOpsServiceProvider);
      final extracted = await ops.extractEditableBoxes(widget.document.path);
      final session = await ops.openPageRenderSession(widget.document.path);
      if (!mounted) {
        await session.close();
        return;
      }
      setState(() {
        _boxes = extracted.boxes;
        _pages = extracted.pages;
        _session = session;
        _loading = false;
      });
      // Prefetch first pages.
      final start = widget.initialPageIndex.clamp(0, _pages.length - 1);
      for (var i = start; i < (start + 3).clamp(0, _pages.length); i++) {
        _ensurePageImage(i);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients || _pages.isEmpty) return;
        // Approximate jump: pages are similar heights after layout — skip for V1.
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _ensurePageImage(int pageIndex) async {
    if (_pageImages.containsKey(pageIndex) ||
        _loadingPages.contains(pageIndex) ||
        _session == null) {
      return;
    }
    _loadingPages.add(pageIndex);
    try {
      final image = await _session!.renderPage(pageIndex);
      if (!mounted) {
        image?.dispose();
        return;
      }
      setState(() => _pageImages[pageIndex] = image);
    } catch (_) {
      if (mounted) setState(() => _pageImages[pageIndex] = null);
    } finally {
      _loadingPages.remove(pageIndex);
    }
  }

  void _select(String? id) {
    setState(() => _selectedId = id);
  }

  PdfEditableBox? get _selected {
    if (_selectedId == null) return null;
    try {
      return _boxes.firstWhere((b) => b.id == _selectedId && !b.deleted);
    } catch (_) {
      return null;
    }
  }

  void _addTextBox(int pageIndex) {
    final metrics = _pages[pageIndex];
    final box = PdfEditableBox(
      id: _uuid.v4(),
      pageIndex: pageIndex,
      originalBounds: Rect.zero,
      bounds: Rect.fromLTWH(
        metrics.width * 0.15,
        metrics.height * 0.2,
        metrics.width * 0.5,
        28,
      ),
      text: 'New text',
      fontSize: 14,
      fontName: 'Helvetica',
      isNew: true,
    )..dirty = true;
    setState(() {
      _boxes.add(box);
      _selectedId = box.id;
    });
    HapticFeedback.selectionClick();
  }

  void _deleteSelected() {
    final box = _selected;
    if (box == null) return;
    setState(() {
      if (box.isNew) {
        _boxes.removeWhere((b) => b.id == box.id);
      } else {
        box.deleted = true;
        box.dirty = true;
      }
      _selectedId = null;
    });
  }

  Future<bool> _confirmExit() async {
    if (!_hasUnsaved) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'You have unsaved text edits. Save before leaving, or exit without saving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'exit'),
            child: const Text('Exit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (choice == 'cancel' || choice == null) return false;
    if (choice == 'exit') return true;
    // Save pops this route with the new document — don't pop again.
    await _save(closeAfter: true);
    return false;
  }

  Future<bool> _save({required bool closeAfter}) async {
    if (!_hasUnsaved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to save.')),
        );
      }
      return true;
    }
    setState(() => _saving = true);
    try {
      final out = await ref.read(pdfOpsServiceProvider).applyEditableBoxes(
            path: widget.document.path,
            boxes: _boxes,
          );
      final baseName = widget.document.name.replaceAll('.pdf', '');
      final item = await ref.read(libraryProvider.notifier).importPath(
            out,
            name: '${baseName}_edited.pdf',
          );
      if (!mounted) return false;
      HapticFeedback.mediumImpact();
      for (final b in _boxes) {
        b.dirty = false;
      }
      if (closeAfter) {
        Navigator.of(context).pop(item);
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = _selected;

    return PopScope(
      canPop: !_hasUnsaved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmExit();
        if (ok && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE8E6E1),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit PDF'),
              Text(
                _hasUnsaved ? 'Unsaved changes' : 'Tap a text box to edit',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              IconButton(
                tooltip: 'Save',
                onPressed: () => _save(closeAfter: true),
                icon: Icon(
                  PhosphorIconsRegular.floppyDisk,
                  color: _hasUnsaved ? colors.primary : null,
                ),
              ),
          ],
        ),
        floatingActionButton: _pages.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () {
                  final page = selected?.pageIndex ??
                      widget.initialPageIndex.clamp(0, _pages.length - 1);
                  _addTextBox(page);
                },
                icon: const Icon(PhosphorIconsRegular.plus),
                label: const Text('Add text'),
                backgroundColor: AppColors.lightAccent,
                foregroundColor: Colors.white,
              ),
        bottomNavigationBar: selected == null
            ? null
            : Material(
                elevation: 8,
                color: colors.surface,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Bold',
                          onPressed: () => setState(
                            () => selected.bold = !selected.bold,
                          ),
                          icon: Icon(
                            PhosphorIconsRegular.textB,
                            color: selected.bold ? colors.primary : null,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Italic',
                          onPressed: () => setState(
                            () => selected.italic = !selected.italic,
                          ),
                          icon: Icon(
                            PhosphorIconsRegular.textItalic,
                            color: selected.italic ? colors.primary : null,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Smaller',
                          onPressed: () => setState(() {
                            selected.setFontSizeFromToolbar(
                              selected.fontSize - 1,
                            );
                            selected.fitHeightToText();
                          }),
                          icon: const Icon(PhosphorIconsRegular.minus),
                        ),
                        Text(
                          '${selected.fontSize.round()}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        IconButton(
                          tooltip: 'Larger',
                          onPressed: () => setState(() {
                            selected.setFontSizeFromToolbar(
                              selected.fontSize + 1,
                            );
                            selected.fitHeightToText();
                          }),
                          icon: const Icon(PhosphorIconsRegular.plus),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Delete text',
                          onPressed: _deleteSelected,
                          icon: Icon(
                            PhosphorIconsRegular.trash,
                            color: colors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_pages.isEmpty) {
      return const Center(child: Text('This PDF has no pages.'));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: _pages.length,
      itemBuilder: (context, pageIndex) {
        _ensurePageImage(pageIndex);
        final metrics = _pages[pageIndex];
        final pageBoxes = _boxes
            .where((b) => b.pageIndex == pageIndex && !b.deleted)
            .toList(growable: false);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _EditablePageCanvas(
            pageIndex: pageIndex,
            metrics: metrics,
            image: _pageImages[pageIndex],
            boxes: pageBoxes,
            selectedId: _selectedId,
            onSelect: _select,
            onChanged: () => setState(() {}),
          ),
        );
      },
    );
  }
}

class _EditablePageCanvas extends StatelessWidget {
  const _EditablePageCanvas({
    required this.pageIndex,
    required this.metrics,
    required this.image,
    required this.boxes,
    required this.selectedId,
    required this.onSelect,
    required this.onChanged,
  });

  final int pageIndex;
  final PdfPageMetrics metrics;
  final ui.Image? image;
  final List<PdfEditableBox> boxes;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final scale = maxW / metrics.width;
        final displayH = metrics.height * scale;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Page ${pageIndex + 1}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => onSelect(null),
              child: Container(
                width: maxW,
                height: displayH,
                decoration: BoxDecoration(
                  color: AppColors.pdfPaper,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (image != null)
                      Positioned.fill(
                        child: RawImage(
                          image: image,
                          fit: BoxFit.fill,
                        ),
                      )
                    else
                      const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    for (final box in boxes)
                      _TextBoxOverlay(
                        box: box,
                        scale: scale,
                        selected: box.id == selectedId,
                        onSelect: () => onSelect(box.id),
                        onChanged: onChanged,
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TextBoxOverlay extends StatefulWidget {
  const _TextBoxOverlay({
    required this.box,
    required this.scale,
    required this.selected,
    required this.onSelect,
    required this.onChanged,
  });

  final PdfEditableBox box;
  final double scale;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onChanged;

  @override
  State<_TextBoxOverlay> createState() => _TextBoxOverlayState();
}

class _TextBoxOverlayState extends State<_TextBoxOverlay> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.box.text);
    _focus = FocusNode();
    _focus.addListener(() {
      if (_focus.hasFocus) widget.onSelect();
    });
  }

  @override
  void didUpdateWidget(covariant _TextBoxOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.box.text != widget.box.text &&
        _controller.text != widget.box.text) {
      _controller.text = widget.box.text;
    }
    if (widget.selected && !_focus.hasFocus) {
      // Keep selection visual without stealing focus every rebuild.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.box;
    final s = widget.scale;
    final left = box.bounds.left * s;
    final top = box.bounds.top * s;
    final width = (box.bounds.width * s).clamp(48.0, 4000.0);
    final fontSize = (box.fontSize * s).clamp(8.0, 96.0);

    // Measure full text so the field is tall/wide enough to read & edit.
    final painter = TextPainter(
      text: TextSpan(
        text: box.text.isEmpty ? ' ' : box.text,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.25,
          fontWeight: box.bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: box.italic ? FontStyle.italic : FontStyle.normal,
          fontFamily: 'Manrope',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: width - 4);
    final height = math
        .max(box.bounds.height * s, painter.height + 8)
        .clamp(20.0, 4000.0);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: widget.onSelect,
        onPanUpdate: widget.selected
            ? (d) {
                box.bounds = box.bounds.shift(
                  Offset(d.delta.dx / s, d.delta.dy / s),
                );
                widget.onChanged();
              }
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.pdfPaper,
                  border: Border.all(
                    color: widget.selected
                        ? AppColors.lightAccent
                        : AppColors.lightAccent.withValues(alpha: 0.45),
                    width: widget.selected ? 1.5 : 1,
                  ),
                ),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.noScaling,
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 1.25,
                      color: AppColors.lightPrimaryText,
                      fontWeight:
                          box.bold ? FontWeight.w700 : FontWeight.w400,
                      fontStyle:
                          box.italic ? FontStyle.italic : FontStyle.normal,
                      fontFamily: 'Manrope',
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      border: InputBorder.none,
                    ),
                    onTap: widget.onSelect,
                    onChanged: (v) {
                      box.text = v;
                      widget.onChanged();
                    },
                  ),
                ),
              ),
            ),
            if (widget.selected)
              Positioned(
                right: -8,
                bottom: -8,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    final next = Rect.fromLTWH(
                      box.bounds.left,
                      box.bounds.top,
                      (box.bounds.width + d.delta.dx / s).clamp(20.0, 2000.0),
                      (box.bounds.height + d.delta.dy / s).clamp(12.0, 2000.0),
                    );
                    box.bounds = next;
                    widget.onChanged();
                  },
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.lightAccent,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Icon(
                      Icons.south_east,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
