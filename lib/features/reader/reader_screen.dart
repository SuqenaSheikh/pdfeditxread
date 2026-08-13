import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/folio_password_field.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/pdf_document_item.dart';
import '../../providers/app_providers.dart';
import '../pro/pro_paywall_screen.dart';
import 'pen_overlay.dart';
import 'pdf_canvas_edit_screen.dart';
import 'selection_context_menu.dart';

enum _AnnotTool { none, highlight, underline, strikethrough, pen }

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.document});

  final PdfDocumentItem document;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  GlobalKey<SfPdfViewerState> _pdfKey = GlobalKey<SfPdfViewerState>();
  final _controller = PdfViewerController();
  final _searchController = TextEditingController();
  final _tts = FlutterTts();

  bool _ttsPlaying = false;
  bool _saving = false;
  bool _searching = false;
  _AnnotTool _tool = _AnnotTool.none;
  Color _markupColor = const Color(0xFFF2B705);
  PdfTextSearchResult? _searchResult;
  int _currentPage = 1;
  int _pageCount = 0;
  late bool _nightMode;
  late PdfPageLayoutMode _layoutMode;
  final List<PenStroke> _penStrokes = [];

  OverlayEntry? _selectionMenuEntry;
  String? _pdfPassword;
  bool _passwordPromptOpen = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _nightMode = settings.nightModeEnabled;
    _layoutMode = settings.readerLayout == ReaderLayoutMode.pageByPage
        ? PdfPageLayoutMode.single
        : PdfPageLayoutMode.continuous;
    _currentPage = widget.document.lastPage.clamp(1, 999999);
  }

  @override
  void dispose() {
    _removeSelectionMenu();
    _searchController.dispose();
    _tts.stop();
    super.dispose();
  }

  void _removeSelectionMenu() {
    _selectionMenuEntry?.remove();
    _selectionMenuEntry?.dispose();
    _selectionMenuEntry = null;
  }

  void _dismissSelectionUi() {
    _removeSelectionMenu();
    _controller.clearSelection();
  }

  Future<void> _persistPage() async {
    await ref.read(libraryProvider.notifier).openTracked(
          widget.document,
          page: _currentPage,
        );
  }

  Future<void> _saveDocument() async {
    setState(() => _saving = true);
    try {
      final bytes = await _controller.saveDocument();
      await File(widget.document.path).writeAsBytes(bytes, flush: true);

      if (_penStrokes.isNotEmpty) {
        final size = MediaQuery.sizeOf(context);
        await ref.read(pdfOpsServiceProvider).bakePenStrokes(
              path: widget.document.path,
              pageOneBased: _currentPage,
              viewSize: size,
              strokes: _penStrokes
                  .map(
                    (s) => (
                      points: s.points,
                      color: s.color,
                      width: s.width,
                    ),
                  )
                  .toList(),
            );
        _penStrokes.clear();
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved into the PDF.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyMarkup(_AnnotTool tool) {
    final lines = _pdfKey.currentState?.getSelectedTextLines() ?? const [];
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select some text first.')),
      );
      return;
    }

    late final Annotation annotation;
    switch (tool) {
      case _AnnotTool.highlight:
        annotation = HighlightAnnotation(textBoundsCollection: lines);
      case _AnnotTool.underline:
        annotation = UnderlineAnnotation(textBoundsCollection: lines);
      case _AnnotTool.strikethrough:
        annotation = StrikethroughAnnotation(textBoundsCollection: lines);
      case _AnnotTool.none:
      case _AnnotTool.pen:
        return;
    }
    annotation.color = _markupColor;
    _controller.addAnnotation(annotation);
    HapticFeedback.selectionClick();
    _dismissSelectionUi();
  }

  void _applySquiggly() {
    final lines = _pdfKey.currentState?.getSelectedTextLines() ?? const [];
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select some text first.')),
      );
      return;
    }
    final annotation = SquigglyAnnotation(textBoundsCollection: lines);
    annotation.color = _markupColor;
    _controller.addAnnotation(annotation);
    HapticFeedback.selectionClick();
    _dismissSelectionUi();
  }

  void _showSelectionMenu(PdfTextSelectionChangedDetails details) {
    _removeSelectionMenu();
    final region = details.globalSelectedRegion;
    if (region == null || !mounted) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final media = MediaQuery.sizeOf(context);
    const menuWidth = 188.0;
    const menuHeight = 280.0;

    var left = region.center.dx - menuWidth / 2;
    var top = region.top - menuHeight - 8;
    if (top < 48) top = region.bottom + 8;
    left = left.clamp(8.0, media.width - menuWidth - 8);
    top = top.clamp(8.0, media.height - menuHeight - 8);

    _selectionMenuEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: left,
        top: top,
        child: SelectionContextMenu(
          onAction: (action) => _onSelectionMenuAction(action, details),
        ),
      ),
    );
    overlay.insert(_selectionMenuEntry!);
  }

  Future<void> _onSelectionMenuAction(
    String action,
    PdfTextSelectionChangedDetails details,
  ) async {
    switch (action) {
      case 'Copy':
        final text = details.selectedText ?? '';
        await Clipboard.setData(ClipboardData(text: text));
        _dismissSelectionUi();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied')),
          );
        }
      case 'Highlight':
        _applyMarkup(_AnnotTool.highlight);
      case 'Underline':
        _applyMarkup(_AnnotTool.underline);
      case 'Strikethrough':
        _applyMarkup(_AnnotTool.strikethrough);
      case 'Squiggly':
        _applySquiggly();
      case 'Edit':
        await _editTextInPlace();
    }
  }

  Future<void> _addStickyNote() async {
    final noteController = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sticky note'),
        content: TextField(
          controller: noteController,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Write a short note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, noteController.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;

    final annotation = StickyNoteAnnotation(
      pageNumber: _currentPage,
      text: text,
      position: const Offset(40, 40),
      icon: PdfStickyNoteIcon.comment,
    );
    annotation.color = AppColors.accentSecondary;
    _controller.addAnnotation(annotation);
    HapticFeedback.selectionClick();
  }

  Future<void> _toggleBookmark() async {
    final lib = ref.read(libraryServiceProvider);
    await lib.togglePageBookmark(
      documentId: widget.document.id,
      pageNumber: _currentPage,
    );
    HapticFeedback.lightImpact();
    setState(() {});
    if (!mounted) return;
    final nowBookmarked =
        lib.hasPageBookmark(widget.document.id, _currentPage);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nowBookmarked
              ? 'Bookmarked page $_currentPage'
              : 'Removed bookmark on page $_currentPage',
        ),
      ),
    );
  }

  Future<void> _showBookmarksSheet() async {
    final lib = ref.read(libraryServiceProvider);
    final bookmarks = lib.bookmarks(widget.document.id);
    await showModalBottomSheet<void>(
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
                      _controller.jumpToPage(b.pageNumber);
                    },
                  ),
                ),
              ListTile(
                leading: const Icon(PhosphorIconsRegular.listBullets),
                title: const Text('Document outline'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pdfKey.currentState?.openBookmarkView();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _runSearch(String query) {
    if (query.trim().isEmpty) {
      _searchResult?.clear();
      setState(() => _searchResult = null);
      return;
    }
    final result = _controller.searchText(query);
    setState(() => _searchResult = result);
  }

  Future<void> _toggleTts() async {
    final isPro = await requirePro(
      context,
      ref,
      featureLabel: 'Text to speech is part of Folio Pro.',
    );
    if (!isPro) return;

    if (_ttsPlaying) {
      await _tts.stop();
      setState(() => _ttsPlaying = false);
      return;
    }

    final text = await ref.read(pdfOpsServiceProvider).extractText(
          widget.document.path,
          pageOneBased: _currentPage,
        );
    if (text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No readable text on this page.')),
      );
      return;
    }

    await _tts.setSpeechRate(0.45);
    await _tts.speak(text);
    setState(() => _ttsPlaying = true);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _ttsPlaying = false);
    });
  }

  Future<void> _openCanvasEdit() async {
    _removeSelectionMenu();
    final isPro = await requirePro(
      context,
      ref,
      featureLabel: 'PDF text editing is part of Folio Pro.',
    );
    if (!isPro || !mounted) return;

    final item = await Navigator.of(context).push<PdfDocumentItem>(
      MaterialPageRoute(
        builder: (_) => PdfCanvasEditScreen(
          document: widget.document,
          initialPageIndex: math.max(0, _currentPage - 1),
        ),
      ),
    );
    if (item == null || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ReaderScreen(document: item)),
    );
  }

  Future<void> _editTextInPlace() async {
    // Prefer Canva-style editor (sticky font sizes, deferred save).
    await _openCanvasEdit();
  }

  Future<void> _promptForPassword({required bool wrongPassword}) async {
    if (_passwordPromptOpen || !mounted) return;
    _passwordPromptOpen = true;
    try {
      final password = await showFolioPasswordDialog(
        context,
        title: 'Password required',
        message: wrongPassword
            ? 'That password did not work. Try again, or cancel to go back.'
            : 'This PDF is protected. Enter the password to open it.',
        confirmLabel: 'Unlock',
        errorText: wrongPassword ? 'Incorrect password' : null,
      );
      if (!mounted) return;
      if (password == null) {
        // Close / Cancel — leave the blank failed viewer.
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _pdfPassword = password;
        _pdfKey = GlobalKey<SfPdfViewerState>();
      });
    } finally {
      _passwordPromptOpen = false;
    }
  }

  void _showAnnotSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Markup', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Highlight'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _tool = _AnnotTool.highlight);
                        _applyMarkup(_AnnotTool.highlight);
                      },
                    ),
                    ActionChip(
                      label: const Text('Underline'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _tool = _AnnotTool.underline);
                        _applyMarkup(_AnnotTool.underline);
                      },
                    ),
                    ActionChip(
                      label: const Text('Strike'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _tool = _AnnotTool.strikethrough);
                        _applyMarkup(_AnnotTool.strikethrough);
                      },
                    ),
                    ActionChip(
                      label: const Text('Squiggly'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _applySquiggly();
                      },
                    ),
                    ActionChip(
                      label: const Text('Note'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _addStickyNote();
                      },
                    ),
                    ActionChip(
                      label: Text(_tool == _AnnotTool.pen ? 'Exit pen' : 'Pen'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _tool = _tool == _AnnotTool.pen
                              ? _AnnotTool.none
                              : _AnnotTool.pen;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Highlight color', style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: AppConstants.highlightColors.map((value) {
                    final color = Color(value);
                    final selected = color.toARGB32() == _markupColor.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        setState(() => _markupColor = color);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Theme.of(ctx).colorScheme.primary
                                : Theme.of(ctx).colorScheme.outline,
                            width: selected ? 2 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookmarked = ref
        .read(libraryServiceProvider)
        .hasPageBookmark(widget.document.id, _currentPage);
    final file = File(widget.document.path);

    // Keep the viewer as the Scaffold body (no Stack overlays on top of it).
    // Floating Stack layers were leaving Syncfusion page tiles unpainted on
    // some MIUI devices even after onDocumentLoaded fired.
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    Widget viewer = SfPdfViewerTheme(
      data: SfPdfViewerThemeData(backgroundColor: scaffoldBg),
      child: SfPdfViewer.file(
        file,
        key: _pdfKey,
        controller: _controller,
        pageLayoutMode: _layoutMode,
        initialPageNumber: _currentPage,
        canShowScrollHead: true,
        canShowPaginationDialog: true,
        canShowPasswordDialog: false,
        password: _pdfPassword,
        enableDoubleTapZooming: true,
        enableTextSelection: true,
        canShowTextSelectionMenu: false,
        onTextSelectionChanged: (details) {
          if (details.selectedText != null &&
              details.selectedText!.isNotEmpty &&
              details.globalSelectedRegion != null) {
            // Defer so Syncfusion finishes laying out selection handles.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (details.selectedText == null ||
                  details.globalSelectedRegion == null) {
                return;
              }
              _showSelectionMenu(details);
            });
          } else {
            _removeSelectionMenu();
          }
        },
        onDocumentLoaded: (details) {
          debugPrint(
            'PDF loaded: ${details.document.pages.count} pages from ${widget.document.path}',
          );
          if (!mounted) return;
          setState(() {
            _pageCount = details.document.pages.count;
            _currentPage = _controller.pageNumber;
          });
        },
        onDocumentLoadFailed: (details) {
          debugPrint(
            'PDF load failed: ${details.error} — ${details.description}',
          );
          if (!mounted) return;
          final blob =
              '${details.error} ${details.description}'.toLowerCase();
          final isPasswordIssue = blob.contains('password') ||
              blob.contains('encrypt') ||
              blob.contains('security');
          if (isPasswordIssue) {
            // Don't snackbar empty-password failures — ask for a password.
            _promptForPassword(
              wrongPassword: _pdfPassword != null && _pdfPassword!.isNotEmpty,
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                details.description.isNotEmpty
                    ? details.description
                    : details.error,
              ),
            ),
          );
        },
        onPageChanged: (details) {
          _removeSelectionMenu();
          setState(() => _currentPage = details.newPageNumber);
          _persistPage();
        },
        onAnnotationAdded: (_) => HapticFeedback.selectionClick(),
      ),
    );

    if (_nightMode) {
      viewer = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: viewer,
      );
    }

    if (_tool == _AnnotTool.pen) {
      viewer = Stack(
        fit: StackFit.expand,
        children: [
          viewer,
          PenOverlay(
            enabled: true,
            color: _markupColor,
            strokes: _penStrokes,
            onStrokesChanged: (strokes) {
              setState(() {
                _penStrokes
                  ..clear()
                  ..addAll(strokes);
              });
              HapticFeedback.selectionClick();
            },
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.document.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _pageCount > 0
                  ? 'Page $_currentPage of $_pageCount'
                  : 'Page $_currentPage',
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
              onPressed: _saveDocument,
              icon: const Icon(PhosphorIconsRegular.floppyDisk),
            ),
          IconButton(
            tooltip: 'Search',
            onPressed: () => setState(() => _searching = !_searching),
            icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
          ),
          IconButton(
            tooltip: 'Markup',
            onPressed: () {
              _removeSelectionMenu();
              _showAnnotSheet();
            },
            icon: const Icon(PhosphorIconsRegular.highlighterCircle),
          ),
          PopupMenuButton<String>(
            onOpened: _removeSelectionMenu,
            onSelected: (value) async {
              switch (value) {
                case 'bookmark':
                  await _toggleBookmark();
                case 'bookmarks':
                  await _showBookmarksSheet();
                case 'night':
                  setState(() => _nightMode = !_nightMode);
                  await ref
                      .read(settingsProvider.notifier)
                      .setNightMode(_nightMode);
                case 'layout':
                  setState(() {
                    _layoutMode =
                        _layoutMode == PdfPageLayoutMode.continuous
                            ? PdfPageLayoutMode.single
                            : PdfPageLayoutMode.continuous;
                    _pdfKey = GlobalKey<SfPdfViewerState>();
                  });
                  await ref.read(settingsProvider.notifier).setReaderLayout(
                        _layoutMode == PdfPageLayoutMode.continuous
                            ? ReaderLayoutMode.continuous
                            : ReaderLayoutMode.pageByPage,
                      );
                case 'tts':
                  await _toggleTts();
                case 'edit':
                  await _editTextInPlace();
                case 'share':
                  await ref
                      .read(libraryServiceProvider)
                      .share(widget.document);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'bookmark',
                child: Text(
                  bookmarked ? 'Remove page bookmark' : 'Bookmark page',
                ),
              ),
              const PopupMenuItem(
                value: 'bookmarks',
                child: Text('All bookmarks / outline'),
              ),
              PopupMenuItem(
                value: 'night',
                child: Text(_nightMode ? 'Exit night mode' : 'Night mode'),
              ),
              PopupMenuItem(
                value: 'layout',
                child: Text(
                  _layoutMode == PdfPageLayoutMode.continuous
                      ? 'Page by page'
                      : 'Continuous scroll',
                ),
              ),
              PopupMenuItem(
                value: 'tts',
                child: Text(_ttsPlaying ? 'Stop reading aloud' : 'Read aloud'),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit PDF text'),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Text('Share'),
              ),
            ],
          ),
        ],
        bottom: _searching
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Find in document',
                            isDense: true,
                          ),
                          onSubmitted: _runSearch,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _runSearch(_searchController.text),
                        icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                      ),
                      IconButton(
                        onPressed: () => _searchResult?.previousInstance(),
                        icon: const Icon(PhosphorIconsRegular.caretUp),
                      ),
                      IconButton(
                        onPressed: () => _searchResult?.nextInstance(),
                        icon: const Icon(PhosphorIconsRegular.caretDown),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: viewer,
    );
  }
}
