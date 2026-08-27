import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:syncfusion_pdfviewer_platform_interface/pdfviewer_platform_interface.dart';

/// Renders PDF pages to [ui.Image] via Syncfusion's platform PdfRenderer.
class PdfPageRenderSession {
  PdfPageRenderSession._({
    required this.documentId,
    required this.pageCount,
    required this.widths,
    required this.heights,
  });

  final String documentId;
  final int pageCount;
  final List<double> widths;
  final List<double> heights;
  bool _closed = false;

  static Future<PdfPageRenderSession> open(String path) async {
    final bytes = await File(path).readAsBytes();
    final documentId = 'folio_edit_${DateTime.now().microsecondsSinceEpoch}';
    try {
      final countStr = await PdfViewerPlatform.instance.initializePdfRenderer(
        bytes,
        documentId,
      );
      final pageCount = int.tryParse(countStr ?? '') ?? 0;
      final widths = await PdfViewerPlatform.instance.getPagesWidth(documentId);
      final heights =
          await PdfViewerPlatform.instance.getPagesHeight(documentId);
      return PdfPageRenderSession._(
        documentId: documentId,
        pageCount: pageCount,
        widths: [
          for (var i = 0; i < (widths?.length ?? 0); i++)
            (widths![i] as num).toDouble(),
        ],
        heights: [
          for (var i = 0; i < (heights?.length ?? 0); i++)
            (heights![i] as num).toDouble(),
        ],
      );
    } catch (e, st) {
      debugPrint('PdfPageRenderSession.open failed: $e\n$st');
      try {
        await PdfViewerPlatform.instance.closeDocument(documentId);
      } catch (_) {}
      rethrow;
    }
  }

  /// Opens a session or returns null — never throws.
  static Future<PdfPageRenderSession?> tryOpen(String path) async {
    try {
      return await open(path);
    } catch (e) {
      debugPrint('PdfPageRenderSession.tryOpen: $e');
      return null;
    }
  }

  Future<ui.Image?> renderPage(int pageIndex, {double maxWidth = 1080}) async {
    if (_closed) return null;
    if (pageIndex < 0 || pageIndex >= pageCount) return null;
    if (pageIndex >= widths.length || pageIndex >= heights.length) return null;
    final pageW = widths[pageIndex];
    final pageH = heights[pageIndex];
    if (pageW <= 0 || pageH <= 0) return null;

    final scale = math.min(1.0, maxWidth / pageW);
    final width = math.max(1, (pageW * scale).round());
    final height = math.max(1, (pageH * scale).round());
    final expectedBytes = width * height * 4;

    try {
      final pixels = await PdfViewerPlatform.instance.getPage(
        pageIndex + 1,
        width,
        height,
        documentId,
      );
      if (_closed) return null;
      if (pixels == null || pixels.length < expectedBytes) return null;

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        width,
        height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return completer.future;
    } catch (e) {
      debugPrint('PdfPageRenderSession.renderPage($pageIndex) failed: $e');
      return null;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await PdfViewerPlatform.instance.closeDocument(documentId);
    } catch (e) {
      debugPrint('PdfPageRenderSession.close failed: $e');
    }
  }
}
