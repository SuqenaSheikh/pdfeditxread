import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/pdf_ops_service.dart';
import '../../providers/app_providers.dart';

/// Loads and caches page bitmaps for tool UIs (reorder / split / delete).
class PageThumbLoader {
  PageThumbLoader(this._ops);

  final PdfOpsService _ops;
  PdfPageRenderSession? _session;
  String? _path;
  Future<void>? _openFuture;
  final Map<int, Uint8List> _cache = {};
  final Map<int, Future<Uint8List?>> _inflight = {};

  Future<void> open(String path) {
    if (_path == path && _session != null) {
      return _openFuture ?? Future.value();
    }
    _openFuture = _openInternal(path);
    return _openFuture!;
  }

  Future<void> _openInternal(String path) async {
    _cache.clear();
    _inflight.clear();
    final previous = _session;
    _session = null;
    _path = null;
    await previous?.close();
    _path = path;
    _session = await _ops.openPageRenderSession(path);
  }

  Future<Uint8List?> thumb(int pageOneBased, {double maxWidth = 420}) async {
    if (_openFuture != null) await _openFuture;
    final session = _session;
    if (session == null) return null;
    final index = pageOneBased - 1;
    if (_cache.containsKey(index)) return _cache[index];
    final existing = _inflight[index];
    if (existing != null) return existing;

    final future = () async {
      final image = await session.renderPage(index, maxWidth: maxWidth);
      if (image == null) return null;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return null;
      final list = bytes.buffer.asUint8List();
      _cache[index] = list;
      return list;
    }();

    _inflight[index] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(index);
    }
  }

  Future<void> close() async {
    _cache.clear();
    _inflight.clear();
    await _session?.close();
    _session = null;
    _path = null;
    _openFuture = null;
  }
}

/// Shows a page thumbnail once loaded.
class PageThumbImage extends StatefulWidget {
  const PageThumbImage({
    super.key,
    required this.loader,
    required this.pageOneBased,
    this.height = 160,
  });

  final PageThumbLoader loader;
  final int pageOneBased;
  final double height;

  @override
  State<PageThumbImage> createState() => _PageThumbImageState();
}

class _PageThumbImageState extends State<PageThumbImage> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PageThumbImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageOneBased != widget.pageOneBased ||
        oldWidget.loader != widget.loader) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _bytes = null;
    });
    final bytes = await widget.loader.thumb(widget.pageOneBased);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        height: widget.height,
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        alignment: Alignment.center,
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : _bytes == null
                ? Icon(Icons.broken_image_outlined, color: colors.outline)
                : Image.memory(
                    _bytes!,
                    fit: BoxFit.contain,
                    height: widget.height,
                  ),
      ),
    );
  }
}

PageThumbLoader createPageThumbLoader(WidgetRef ref) {
  return PageThumbLoader(ref.read(pdfOpsServiceProvider));
}
