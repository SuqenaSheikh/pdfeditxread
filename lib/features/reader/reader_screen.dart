import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/pdf_document_item.dart';
import '../../providers/app_providers.dart';
import '../pro/pro_paywall_screen.dart';
import 'pen_overlay.dart';

enum _AnnotTool { none, highlight, underline, strikethrough, pen, note }

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.document});

  final PdfDocumentItem document;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _pdfKey = GlobalKey<SfPdfViewerState>();
  final _controller = PdfViewerController();
  final _searchController = TextEditingController();
  final _tts = FlutterTts();

  bool _chromeVisible = true;
  bool _searchOpen = false;
  bool _ttsPlaying = false;
  bool _saving = false;
  _AnnotTool _tool = _AnnotTool.none;
  Color _markupColor = const Color(0xFFF2B705);
  PdfTextSearchResult? _searchResult;
  int _currentPage = 1;
  late bool _nightMode;
  late PdfPageLayoutMode _layoutMode;
  final List<PenStroke> _penStrokes = [];
  final _viewerBoxKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _nightMode = settings.nightModeEnabled;
    _layoutMode = settings.readerLayout == ReaderLayoutMode.pageByPage
        ? PdfPageLayoutMode.single
        : PdfPageLayoutMode.continuous;
    _currentPage = widget.document.lastPage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPage > 1) _controller.jumpToPage(_currentPage);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    _tts.stop();
    super.dispose();
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
        final box =
            _viewerBoxKey.currentContext?.findRenderObject() as RenderBox?;
        final size = box?.size ?? MediaQuery.sizeOf(context);
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

  void _applyMarkup() {
    final lines = _pdfKey.currentState?.getSelectedTextLines() ?? const [];
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select some text first.')),
      );
      return;
    }

    late final Annotation annotation;
    switch (_tool) {
      case _AnnotTool.highlight:
        annotation = HighlightAnnotation(textBoundsCollection: lines);
      case _AnnotTool.underline:
        annotation = UnderlineAnnotation(textBoundsCollection: lines);
      case _AnnotTool.strikethrough:
        annotation = StrikethroughAnnotation(textBoundsCollection: lines);
      default:
        return;
    }
    annotation.color = _markupColor;
    _controller.addAnnotation(annotation);
    HapticFeedback.selectionClick();
  }

  Future<void> _addStickyNote(PdfGestureDetails details) async {
    if (details.pageNumber < 1) return;
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
      pageNumber: details.pageNumber,
      text: text,
      position: details.pagePosition,
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

  Future<void> _editTextInPlace() async {
    final isPro = await requirePro(
      context,
      ref,
      featureLabel: 'In-place text editing is part of Folio Pro.',
    );
    if (!isPro || !mounted) return;

    final lines = _pdfKey.currentState?.getSelectedTextLines() ?? const [];
    final selected = lines.map((l) => l.text).join(' ').trim();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the text you want to replace first.'),
        ),
      );
      return;
    }

    final controller = TextEditingController(text: selected);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (next == null || next == selected) return;

    // Cover-and-redraw fallback (spec section 5.4) using page text bounds.
    try {
      if (lines.isEmpty) {
        throw StateError('Could not resolve text bounds.');
      }
      final bounds = lines.first.bounds;
      final pageIndex = math.max(0, lines.first.pageNumber - 1);
      final out = await ref.read(pdfOpsServiceProvider).replaceTextOnPage(
            path: widget.document.path,
            pageIndexZeroBased: pageIndex,
            bounds: bounds,
            newText: next,
            fontSize: bounds.height.clamp(8, 28),
          );
      final baseName = widget.document.name.replaceAll('.pdf', '');
      final item = await ref.read(libraryProvider.notifier).importPath(
            out,
            name: '${baseName}_edited.pdf',
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ReaderScreen(document: item)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not edit text: $e')),
      );
    }
  }

  Widget _buildViewer() {
    final viewer = SfPdfViewer.file(
      File(widget.document.path),
      key: _pdfKey,
      controller: _controller,
      pageLayoutMode: _layoutMode,
      canShowScrollHead: true,
      canShowPaginationDialog: true,
      canShowPasswordDialog: true,
      enableDoubleTapZooming: true,
      enableTextSelection: true,
      onPageChanged: (details) {
        setState(() => _currentPage = details.newPageNumber);
        _persistPage();
      },
      onTap: (details) {
        if (_tool == _AnnotTool.note) {
          _addStickyNote(details);
          return;
        }
        setState(() => _chromeVisible = !_chromeVisible);
      },
      onAnnotationAdded: (_) => HapticFeedback.selectionClick(),
    );

    if (!_nightMode) return viewer;

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -1, 0, 0, 0, 255,
        0, -1, 0, 0, 255,
        0, 0, -1, 0, 255,
        0, 0, 0, 1, 0,
      ]),
      child: viewer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bookmarked = ref
        .read(libraryServiceProvider)
        .hasPageBookmark(widget.document.id, _currentPage);

    return Scaffold(
      backgroundColor: _nightMode ? Colors.black : AppColors.pdfPaper,
      body: Stack(
        children: [
          Positioned.fill(
            child: KeyedSubtree(
              key: _viewerBoxKey,
              child: _buildViewer(),
            ),
          ),
          PenOverlay(
            enabled: _tool == _AnnotTool.pen,
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
          if (_chromeVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopChrome(
                title: widget.document.name,
                pageLabel: '$_currentPage',
                bookmarked: bookmarked,
                saving: _saving,
                nightMode: _nightMode,
                continuous: _layoutMode == PdfPageLayoutMode.continuous,
                searchOpen: _searchOpen,
                searchController: _searchController,
                searchResult: _searchResult,
                onBack: () => Navigator.pop(context),
                onSave: _saveDocument,
                onShare: () =>
                    ref.read(libraryServiceProvider).share(widget.document),
                onToggleBookmark: _toggleBookmark,
                onBookmarks: _showBookmarksSheet,
                onToggleNight: () {
                  setState(() => _nightMode = !_nightMode);
                  ref
                      .read(settingsProvider.notifier)
                      .setNightMode(_nightMode);
                },
                onToggleLayout: () {
                  setState(() {
                    _layoutMode =
                        _layoutMode == PdfPageLayoutMode.continuous
                            ? PdfPageLayoutMode.single
                            : PdfPageLayoutMode.continuous;
                  });
                  ref.read(settingsProvider.notifier).setReaderLayout(
                        _layoutMode == PdfPageLayoutMode.continuous
                            ? ReaderLayoutMode.continuous
                            : ReaderLayoutMode.pageByPage,
                      );
                },
                onToggleSearch: () {
                  setState(() {
                    _searchOpen = !_searchOpen;
                    if (!_searchOpen) {
                      _searchResult?.clear();
                      _searchResult = null;
                      _searchController.clear();
                    }
                  });
                },
                onSearch: _runSearch,
                onSearchNext: () => _searchResult?.nextInstance(),
                onSearchPrev: () => _searchResult?.previousInstance(),
                onTts: _toggleTts,
                ttsPlaying: _ttsPlaying,
                onEditText: _editTextInPlace,
              ),
            ),
          if (_chromeVisible)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: _BottomTools(
                tool: _tool,
                markupColor: _markupColor,
                onToolSelected: (t) {
                  setState(() => _tool = t);
                  if (t == _AnnotTool.highlight ||
                      t == _AnnotTool.underline ||
                      t == _AnnotTool.strikethrough) {
                    _applyMarkup();
                  }
                },
                onColorSelected: (c) => setState(() => _markupColor = c),
              ),
            ),
          if (_tool == _AnnotTool.pen)
            Positioned(
              right: 16,
              bottom: 96,
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(
                    'Draw freely, then tap Save',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.title,
    required this.pageLabel,
    required this.bookmarked,
    required this.saving,
    required this.nightMode,
    required this.continuous,
    required this.searchOpen,
    required this.searchController,
    required this.searchResult,
    required this.onBack,
    required this.onSave,
    required this.onShare,
    required this.onToggleBookmark,
    required this.onBookmarks,
    required this.onToggleNight,
    required this.onToggleLayout,
    required this.onToggleSearch,
    required this.onSearch,
    required this.onSearchNext,
    required this.onSearchPrev,
    required this.onTts,
    required this.ttsPlaying,
    required this.onEditText,
  });

  final String title;
  final String pageLabel;
  final bool bookmarked;
  final bool saving;
  final bool nightMode;
  final bool continuous;
  final bool searchOpen;
  final TextEditingController searchController;
  final PdfTextSearchResult? searchResult;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onToggleBookmark;
  final VoidCallback onBookmarks;
  final VoidCallback onToggleNight;
  final VoidCallback onToggleLayout;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearch;
  final VoidCallback onSearchNext;
  final VoidCallback onSearchPrev;
  final VoidCallback onTts;
  final bool ttsPlaying;
  final VoidCallback onEditText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface.withValues(alpha: 0.96),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(PhosphorIconsRegular.arrowLeft),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Page $pageLabel',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (saving)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Save',
                    onPressed: onSave,
                    icon: const Icon(PhosphorIconsRegular.floppyDisk),
                  ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: onShare,
                  icon: const Icon(PhosphorIconsRegular.shareNetwork),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'bookmark':
                        onToggleBookmark();
                      case 'bookmarks':
                        onBookmarks();
                      case 'night':
                        onToggleNight();
                      case 'layout':
                        onToggleLayout();
                      case 'search':
                        onToggleSearch();
                      case 'tts':
                        onTts();
                      case 'edit':
                        onEditText();
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
                      child: Text(nightMode ? 'Exit night mode' : 'Night mode'),
                    ),
                    PopupMenuItem(
                      value: 'layout',
                      child: Text(
                        continuous ? 'Page by page' : 'Continuous scroll',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'search',
                      child: Text('Search in file'),
                    ),
                    PopupMenuItem(
                      value: 'tts',
                      child: Text(ttsPlaying ? 'Stop reading aloud' : 'Read aloud'),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit selected text'),
                    ),
                  ],
                ),
              ],
            ),
            if (searchOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Find in document',
                          isDense: true,
                        ),
                        onSubmitted: onSearch,
                      ),
                    ),
                    IconButton(
                      onPressed: () => onSearch(searchController.text),
                      icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                    ),
                    IconButton(
                      onPressed: onSearchPrev,
                      icon: const Icon(PhosphorIconsRegular.caretUp),
                    ),
                    IconButton(
                      onPressed: onSearchNext,
                      icon: const Icon(PhosphorIconsRegular.caretDown),
                    ),
                    if (searchResult != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '${searchResult!.currentInstanceIndex}/${searchResult!.totalInstanceCount}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            Divider(height: 1, color: colors.outline),
          ],
        ),
      ),
    );
  }
}

class _BottomTools extends StatelessWidget {
  const _BottomTools({
    required this.tool,
    required this.markupColor,
    required this.onToolSelected,
    required this.onColorSelected,
  });

  final _AnnotTool tool;
  final Color markupColor;
  final ValueChanged<_AnnotTool> onToolSelected;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tool == _AnnotTool.highlight ||
            tool == _AnnotTool.underline ||
            tool == _AnnotTool.strikethrough)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.outline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: AppConstants.highlightColors.map((value) {
                final color = Color(value);
                final selected = color.toARGB32() == markupColor.toARGB32();
                return GestureDetector(
                  onTap: () => onColorSelected(color),
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? colors.primary : colors.outline,
                        width: selected ? 2 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ToolBtn(
                icon: PhosphorIconsRegular.highlighterCircle,
                label: 'Highlight',
                selected: tool == _AnnotTool.highlight,
                onTap: () => onToolSelected(_AnnotTool.highlight),
              ),
              _ToolBtn(
                icon: PhosphorIconsRegular.textUnderline,
                label: 'Underline',
                selected: tool == _AnnotTool.underline,
                onTap: () => onToolSelected(_AnnotTool.underline),
              ),
              _ToolBtn(
                icon: PhosphorIconsRegular.textStrikethrough,
                label: 'Strike',
                selected: tool == _AnnotTool.strikethrough,
                onTap: () => onToolSelected(_AnnotTool.strikethrough),
              ),
              _ToolBtn(
                icon: PhosphorIconsRegular.pencil,
                label: 'Pen',
                selected: tool == _AnnotTool.pen,
                onTap: () => onToolSelected(_AnnotTool.pen),
              ),
              _ToolBtn(
                icon: PhosphorIconsRegular.noteBlank,
                label: 'Note',
                selected: tool == _AnnotTool.note,
                onTap: () => onToolSelected(_AnnotTool.note),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
