import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/pdf_document_item.dart';
import '../../data/services/pdf_font_catalog.dart';
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
                    for (final box in (() {
                      // Selected box on top so Transparent neighbors don't steal taps.
                      final ordered = List<PdfEditableBox>.from(boxes);
                      if (selectedId != null) {
                        ordered.sort((a, b) {
                          if (a.id == selectedId) return 1;
                          if (b.id == selectedId) return -1;
                          return 0;
                        });
                      }
                      return ordered;
                    })())
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
    if (oldWidget.selected && !widget.selected && _focus.hasFocus) {
      _focus.unfocus();
    }
    if (!oldWidget.selected && widget.selected) {
      // Tap selected the box — open the keyboard on the next frame once
      // the TextField exists in the tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.selected) return;
        _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  TextStyle _pdfLikeStyle(double fontSize, {required Color color}) {
    final box = widget.box;
    final nameLower = box.fontName.toLowerCase();
    // Never use PDF-embedded subset TTFs in Flutter TextFields — their cmaps
    // often are not Unicode and render as □ tofu boxes. Save still uses the
    // real embedded face via PdfTrueTypeFont.
    final family =
        PdfEmbeddedFontCatalog.flutterFallbackFamily(box.fontName);
    final synthesizeBold = box.bold &&
        !nameLower.contains('bold') &&
        !nameLower.contains('black');
    final synthesizeItalic = box.italic &&
        !nameLower.contains('italic') &&
        !nameLower.contains('oblique');

    return TextStyle(
      fontSize: fontSize,
      height: 1.0,
      leadingDistribution: TextLeadingDistribution.even,
      color: color,
      fontWeight: synthesizeBold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: synthesizeItalic ? FontStyle.italic : FontStyle.normal,
      fontFamily: family,
      fontFamilyFallback: const [
        'Roboto',
        'Noto Sans',
        'Helvetica',
        'Arial',
        'sans-serif',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.box;
    final s = widget.scale;
    final glyphW = math.max(box.bounds.width * s, 8.0);
    final glyphH = math.max(box.bounds.height * s, 8.0);
    // Cap display size to the glyph slot so text cannot spill onto neighbors.
    final fontSize = math
        .min(box.fontSize * s, glyphH)
        .clamp(5.0, 96.0);

    // Editor chrome only while selected. Dirty+deselected → in-place preview.
    final isEditing = widget.selected;
    final showPaintedText = isEditing || box.dirty || box.isNew;
    final multiline = box.text.contains('\n');

    final style = _pdfLikeStyle(
      fontSize,
      color: AppColors.lightPrimaryText,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: box.text.isEmpty ? ' ' : box.text,
        style: style,
      ),
      textDirection: TextDirection.ltr,
      maxLines: multiline ? null : 1,
    )..layout(maxWidth: multiline ? glyphW : 10000);

    // Grow right only when text is longer; keep the original top-left anchor.
    // While editing, use a comfortable tap height so the keyboard can open.
    final width = math.max(glyphW, painter.width + (isEditing ? 2.0 : 0.5));
    final height = isEditing
        ? math.max(math.max(glyphH, multiline ? painter.height : glyphH), 32.0)
        : (multiline ? math.max(glyphH, painter.height) : glyphH);

    final left = box.bounds.left * s;
    final top = box.bounds.top * s;

    final field = MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.noScaling,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          maxLines: multiline ? null : 1,
          expands: multiline,
          cursorColor: AppColors.lightAccent,
          textAlignVertical: TextAlignVertical.center,
          keyboardType:
              multiline ? TextInputType.multiline : TextInputType.text,
          enableInteractiveSelection: true,
          style: style,
          decoration: const InputDecoration(
            isDense: true,
            filled: false,
            fillColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onTap: () {
            widget.onSelect();
            _focus.requestFocus();
          },
          onChanged: (v) {
            box.text = v;
            widget.onChanged();
          },
        ),
      ),
    );

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRect(
            child: ColoredBox(
              color: showPaintedText
                  ? AppColors.pdfPaper
                  : Colors.transparent,
              // Important: do NOT wrap the TextField in a GestureDetector that
              // steals taps — that blocked keyboard/editing after selection.
              child: isEditing
                  ? field
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onSelect,
                      child: showPaintedText
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                box.text,
                                maxLines: multiline ? null : 1,
                                softWrap: multiline,
                                overflow: TextOverflow.visible,
                                style: style,
                              ),
                            )
                          : const SizedBox.expand(),
                    ),
            ),
          ),
          if (isEditing)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.lightAccent,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          // Drag from the top edge only — keeps typing gestures free.
          if (isEditing)
            Positioned(
              left: 0,
              right: 18,
              top: 0,
              height: 10,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  box.bounds = box.bounds.shift(
                    Offset(d.delta.dx / s, d.delta.dy / s),
                  );
                  widget.onChanged();
                },
                child: const ColoredBox(color: Color(0x00000000)),
              ),
            ),
          if (isEditing)
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
    );
  }
}
