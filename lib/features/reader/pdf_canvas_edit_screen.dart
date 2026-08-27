import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/pdf_document_item.dart';
import '../../data/services/pdf/pdf_page_render_session.dart';
import '../../providers/app_providers.dart';
import 'editable_text_box.dart';
import 'widgets/canvas_edit_format_bar.dart';
import 'widgets/editable_page_canvas.dart';

/// Overlay editor: add, move, and save new text on page images.
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
  final Map<int, GlobalKey> _canvasKeys = {};

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
    await WidgetsBinding.instance.endOfFrame;
    try {
      final ops = ref.read(pdfOpsServiceProvider);
      final pages = await ops.pageMetrics(widget.document.path);
      if (!mounted) return;
      final session = await PdfPageRenderSession.tryOpen(widget.document.path);
      if (!mounted) {
        await session?.close();
        return;
      }
      setState(() {
        _boxes = [];
        _pages = pages;
        _session = session;
        _loading = false;
      });
      if (_pages.isEmpty) return;
      final last = _pages.length - 1;
      final start = widget.initialPageIndex.clamp(0, last);
      _ensurePageImage(start);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToPage(start);
      });
    } catch (e, st) {
      debugPrint('Add text bootstrap failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not open this PDF.\n$e';
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
      final image = await _session!.renderPage(pageIndex, maxWidth: 800);
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
    if (id == null) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
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

  GlobalKey _canvasKeyFor(int pageIndex) {
    return _canvasKeys.putIfAbsent(pageIndex, GlobalKey.new);
  }

  void _scrollToPage(int pageIndex) {
    final ctx = _canvasKeyFor(pageIndex).currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.12,
      duration: const Duration(milliseconds: 250),
    );
  }

  RenderBox? _listViewport() {
    if (_scrollController.hasClients) {
      final box = _scrollController.position.context.notificationContext
          ?.findRenderObject();
      if (box is RenderBox && box.hasSize) return box;
    }
    final fallback = context.findRenderObject();
    return fallback is RenderBox && fallback.hasSize ? fallback : null;
  }

  int _visiblePageIndex() {
    final viewBox = _listViewport();
    if (viewBox == null) {
      return widget.initialPageIndex.clamp(0, math.max(0, _pages.length - 1)).toInt();
    }
    final viewTop = viewBox.localToGlobal(Offset.zero).dy;
    final viewCenterY = viewTop + viewBox.size.height / 2;

    var best =
        widget.initialPageIndex.clamp(0, math.max(0, _pages.length - 1)).toInt();
    var bestDist = double.infinity;
    for (var i = 0; i < _pages.length; i++) {
      final box =
          _canvasKeyFor(i).currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final mid = top + box.size.height / 2;
      final dist = (mid - viewCenterY).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    return best;
  }

  Rect _boundsOnVisiblePage(int pageIndex) {
    final metrics = _pages[pageIndex];
    final boxW = metrics.width * 0.55;
    final boxH = 40.0;
    var pdfX = (metrics.width - boxW) / 2;
    var pdfY = metrics.height * 0.35;

    final pageBox =
        _canvasKeyFor(pageIndex).currentContext?.findRenderObject() as RenderBox?;
    final viewBox = _listViewport();
    if (pageBox != null && pageBox.hasSize && viewBox != null) {
      final viewCenter = viewBox.localToGlobal(
        Offset(viewBox.size.width / 2, viewBox.size.height / 2),
      );
      final local = pageBox.globalToLocal(viewCenter);
      final scale = pageBox.size.width / metrics.width;
      if (scale > 0) {
        pdfX = local.dx / scale - boxW / 2;
        pdfY = local.dy / scale - boxH / 2;
      }
    }

    final maxX = math.max(0.0, metrics.width - boxW);
    final maxY = math.max(0.0, metrics.height - boxH);
    return Rect.fromLTWH(
      pdfX.clamp(0.0, maxX),
      pdfY.clamp(0.0, maxY),
      boxW,
      boxH,
    );
  }

  void _addTextBox() {
    if (_pages.isEmpty) return;
    final pageIndex = _visiblePageIndex();
    final box = PdfEditableBox(
      id: _uuid.v4(),
      pageIndex: pageIndex,
      bounds: _boundsOnVisiblePage(pageIndex),
      text: '',
      fontSize: 14,
    );
    setState(() {
      _boxes.add(box);
      _selectedId = box.id;
    });
    HapticFeedback.selectionClick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToPage(pageIndex);
    });
  }

  void _deleteSelected() {
    final box = _selected;
    if (box == null) return;
    setState(() {
      _boxes.removeWhere((b) => b.id == box.id);
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
          'Your text is not saved yet. Save the PDF, or discard and exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'exit'),
            child: const Text('Discard'),
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
      final out = await ref.read(pdfOpsServiceProvider).applyAddedText(
            path: widget.document.path,
            boxes: _boxes,
          );
      final baseName = widget.document.name.replaceAll('.pdf', '');
      final item = await ref.read(libraryProvider.notifier).importPath(
            out,
            name: '${baseName}_text.pdf',
          );
      if (!mounted) return false;
      HapticFeedback.mediumImpact();
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
              const Text('Add text'),
              Text(
                _hasUnsaved
                    ? 'Unsaved — tap save when ready'
                    : 'Drag a box to place it · pinch to zoom',
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
                onPressed: _addTextBox,
                icon: const Icon(PhosphorIconsRegular.plus),
                label: const Text('Add text'),
                backgroundColor: AppColors.lightAccent,
                foregroundColor: Colors.white,
              ),
        bottomNavigationBar: selected == null
            ? null
            : CanvasEditFormatBar(
                selected: selected,
                onChanged: () => setState(() {}),
                onDelete: _deleteSelected,
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
          child: EditablePageCanvas(
            pageIndex: pageIndex,
            metrics: metrics,
            image: _pageImages[pageIndex],
            boxes: pageBoxes,
            selectedId: _selectedId,
            canvasKey: _canvasKeyFor(pageIndex),
            onSelect: _select,
            onChanged: () => setState(() {}),
          ),
        );
      },
    );
  }
}
