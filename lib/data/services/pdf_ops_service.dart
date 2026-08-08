import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_pdfviewer_platform_interface/pdfviewer_platform_interface.dart';
import 'package:uuid/uuid.dart';

import '../../features/reader/editable_text_box.dart';

/// Structural PDF operations (merge, split, reorder, delete, encrypt, export).
class PdfOpsService {
  Future<String> merge(List<String> paths, {String? outputName}) async {
    if (paths.length < 2) {
      throw ArgumentError('Pick at least two PDFs to merge.');
    }

    final merged = PdfDocument();
    final sources = <PdfDocument>[];
    try {
      for (final path in paths) {
        final source = PdfDocument(inputBytes: await File(path).readAsBytes());
        sources.add(source);
        for (var i = 0; i < source.pages.count; i++) {
          final template = source.pages[i].createTemplate();
          merged.pages.add().graphics.drawPdfTemplate(
                template,
                Offset.zero,
                Size(template.size.width, template.size.height),
              );
        }
      }
      final bytes = Uint8List.fromList(merged.saveSync());
      return _writeOutput(
        bytes,
        outputName ?? 'merged_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } finally {
      merged.dispose();
      for (final d in sources) {
        d.dispose();
      }
    }
  }

  Future<List<String>> split(
    String path, {
    required List<(int start, int end)> ranges,
  }) async {
    final sourceBytes = await File(path).readAsBytes();
    final outputs = <String>[];
    final base = p.basenameWithoutExtension(path);

    for (var r = 0; r < ranges.length; r++) {
      final (start, end) = ranges[r];
      final source = PdfDocument(inputBytes: sourceBytes);
      final target = PdfDocument();
      try {
        for (var i = start; i <= end; i++) {
          if (i < 1 || i > source.pages.count) continue;
          final template = source.pages[i - 1].createTemplate();
          target.pages.add().graphics.drawPdfTemplate(
                template,
                Offset.zero,
                Size(template.size.width, template.size.height),
              );
        }
        final bytes = Uint8List.fromList(target.saveSync());
        outputs.add(await _writeOutput(bytes, '${base}_part${r + 1}.pdf'));
      } finally {
        target.dispose();
        source.dispose();
      }
    }
    return outputs;
  }

  Future<String> reorder(String path, List<int> newOrderOneBased) async {
    final source = PdfDocument(inputBytes: await File(path).readAsBytes());
    final target = PdfDocument();
    try {
      for (final pageNum in newOrderOneBased) {
        final template = source.pages[pageNum - 1].createTemplate();
        target.pages.add().graphics.drawPdfTemplate(
              template,
              Offset.zero,
              Size(template.size.width, template.size.height),
            );
      }
      final bytes = Uint8List.fromList(target.saveSync());
      return _writeOutput(
        bytes,
        '${p.basenameWithoutExtension(path)}_reordered.pdf',
      );
    } finally {
      target.dispose();
      source.dispose();
    }
  }

  Future<String> deletePages(String path, List<int> pagesOneBased) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    try {
      final sorted = [...pagesOneBased]..sort((a, b) => b.compareTo(a));
      for (final page in sorted) {
        if (page >= 1 && page <= doc.pages.count) {
          doc.pages.removeAt(page - 1);
        }
      }
      final bytes = Uint8List.fromList(doc.saveSync());
      return _writeOutput(
        bytes,
        '${p.basenameWithoutExtension(path)}_edited.pdf',
      );
    } finally {
      doc.dispose();
    }
  }

  Future<String> protectWithPassword(
    String path, {
    required String userPassword,
  }) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    try {
      final security = doc.security;
      security.userPassword = userPassword;
      security.ownerPassword = '${userPassword}_owner';
      security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
      final bytes = Uint8List.fromList(doc.saveSync());
      return _writeOutput(
        bytes,
        '${p.basenameWithoutExtension(path)}_protected.pdf',
      );
    } finally {
      doc.dispose();
    }
  }

  Future<List<String>> exportPagesAsImages(
    String path, {
    required String format,
    int quality = 90,
  }) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    final outputs = <String>[];
    final base = p.basenameWithoutExtension(path);
    final dir = await _exportsDir();

    try {
      for (var i = 0; i < doc.pages.count; i++) {
        final page = doc.pages[i];
        final width = page.size.width.round().clamp(320, 1600);
        final height = page.size.height.round().clamp(420, 2200);

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);

        final border = Paint()
          ..color = const Color(0xFFE7E5E0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRect(
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          border,
        );

        final label = TextPainter(
          text: TextSpan(
            text: 'Page ${i + 1}\n$base',
            style: const TextStyle(
              color: Color(0xFF6B6B70),
              fontSize: 22,
              fontFamily: 'Manrope',
              height: 1.3,
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: width.toDouble() - 40);
        label.paint(
          canvas,
          Offset(
            (width - label.width) / 2,
            (height - label.height) / 2,
          ),
        );

        final image =
            await recorder.endRecording().toImage(width, height);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;

        var bytes = byteData.buffer.asUint8List();
        final ext = format.toLowerCase() == 'jpg' ? 'jpg' : 'png';
        final outPath = p.join(dir.path, '${base}_page${i + 1}.$ext');

        if (ext == 'jpg') {
          final compressed = await FlutterImageCompress.compressWithList(
            bytes,
            format: CompressFormat.jpeg,
            quality: quality,
          );
          bytes = Uint8List.fromList(compressed);
        }
        await File(outPath).writeAsBytes(bytes);
        outputs.add(outPath);
      }
    } finally {
      doc.dispose();
    }
    return outputs;
  }

  /// Cover-and-redraw in-place text edit (FR-14 fallback from the spec).
  ///
  /// [lineBounds] are page-space rects from the viewer selection. The original
  /// glyphs are painted over, then [newText] is drawn into the same area using
  /// font metadata from the PDF text layer when available.
  Future<String> replaceTextOnPage({
    required String path,
    required int pageIndexZeroBased,
    required List<Rect> lineBounds,
    required String newText,
    required String selectedText,
    bool bold = false,
    bool italic = false,
    Color coverColor = const Color(0xFFFFFFFF),
  }) async {
    if (lineBounds.isEmpty) {
      throw ArgumentError('No text bounds to replace.');
    }

    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    try {
      if (pageIndexZeroBased < 0 ||
          pageIndexZeroBased >= doc.pages.count) {
        throw RangeError('Page index out of range: $pageIndexZeroBased');
      }

      final page = doc.pages[pageIndexZeroBased];
      final g = page.graphics;

      var cover = lineBounds.first;
      for (final rect in lineBounds.skip(1)) {
        cover = cover.expandToInclude(rect);
      }

      final avgLineHeight = lineBounds
              .map((r) => r.height)
              .fold<double>(0, (a, b) => a + b) /
          lineBounds.length;

      final matched = _matchTextStyle(
        doc: doc,
        pageIndexZeroBased: pageIndexZeroBased,
        selectedText: selectedText,
        cover: cover,
      );

      final family = _mapFontFamily(matched.fontName);
      final styles = <PdfFontStyle>{
        ...matched.styles,
        if (bold) PdfFontStyle.bold,
        if (italic) PdfFontStyle.italic,
      };

      // Keep the exact PDF text-layer size of the selection — never rescale.
      final fontSize = (matched.fontSize > 0
              ? matched.fontSize
              : avgLineHeight)
          .clamp(1.0, 200.0);

      final font = PdfStandardFont(
        family,
        fontSize,
        multiStyle: styles.toList(growable: false),
      );

      final brush = PdfSolidBrush(PdfColor(28, 28, 30));
      final coverBrush = PdfSolidBrush(
        PdfColor(
          (coverColor.r * 255.0).round().clamp(0, 255),
          (coverColor.g * 255.0).round().clamp(0, 255),
          (coverColor.b * 255.0).round().clamp(0, 255),
        ),
      );

      final paintCover = Rect.fromLTRB(
        cover.left - 1.2,
        cover.top - 1.2,
        cover.right + 2.4,
        cover.bottom + 1.8,
      );

      g.drawRectangle(bounds: paintCover, brush: coverBrush);

      final textBounds = Rect.fromLTWH(
        cover.left,
        cover.top,
        math.max(cover.width, 8),
        // Keep draw height tied to font size so re-selecting doesn't grow.
        fontSize * 1.25,
      );

      final format = PdfStringFormat(
        alignment: PdfTextAlignment.left,
        lineAlignment: PdfVerticalAlignment.top,
        wordWrap: PdfWordWrapType.word,
      )
        ..lineLimit = false
        ..noClip = true;

      g.drawString(
        newText,
        font,
        bounds: textBounds,
        brush: brush,
        format: format,
      );

      final bytes = Uint8List.fromList(doc.saveSync());
      return _writeOutput(
        bytes,
        '${p.basenameWithoutExtension(path)}_textedit.pdf',
      );
    } finally {
      doc.dispose();
    }
  }

  ({String fontName, double fontSize, List<PdfFontStyle> styles})
      _matchTextStyle({
    required PdfDocument doc,
    required int pageIndexZeroBased,
    required String selectedText,
    required Rect cover,
  }) {
    try {
      final lines = PdfTextExtractor(doc).extractTextLines(
        startPageIndex: pageIndexZeroBased,
        endPageIndex: pageIndexZeroBased,
      );
      final needle = selectedText.trim().toLowerCase();
      TextLine? bestLine;
      var bestLineScore = 0.0;
      TextWord? bestWord;
      var bestWordScore = 0.0;

      for (final line in lines) {
        final lineOverlap = cover.intersect(line.bounds);
        if (!lineOverlap.isEmpty) {
          final area = lineOverlap.width * lineOverlap.height;
          final lineArea =
              math.max(line.bounds.width * line.bounds.height, 1.0);
          var score = area / lineArea;
          if (needle.isNotEmpty &&
              line.text.toLowerCase().contains(needle)) {
            score += 2;
          }
          if (score > bestLineScore) {
            bestLineScore = score;
            bestLine = line;
          }
        }

        for (final word in line.wordCollection) {
          final wordOverlap = cover.intersect(word.bounds);
          if (wordOverlap.isEmpty) continue;
          final area = wordOverlap.width * wordOverlap.height;
          final wordArea =
              math.max(word.bounds.width * word.bounds.height, 1.0);
          var score = area / wordArea;
          final wordText = word.text.trim().toLowerCase();
          if (needle.isNotEmpty &&
              (needle.contains(wordText) || wordText.contains(needle))) {
            score += 3;
          }
          if (score > bestWordScore) {
            bestWordScore = score;
            bestWord = word;
          }
        }
      }

      // Prefer the word-level size of the selection when available.
      if (bestWord != null && bestWord.fontSize > 0) {
        return (
          fontName: bestWord.fontName.isNotEmpty
              ? bestWord.fontName
              : (bestLine?.fontName ?? 'Helvetica'),
          fontSize: bestWord.fontSize,
          styles: List<PdfFontStyle>.from(
            bestWord.fontStyle.isNotEmpty
                ? bestWord.fontStyle
                : (bestLine?.fontStyle ?? const <PdfFontStyle>[]),
          ),
        );
      }

      if (bestLine != null) {
        var size = bestLine.fontSize;
        if (size <= 0 && bestLine.wordCollection.isNotEmpty) {
          final sizes = bestLine.wordCollection
              .map((w) => w.fontSize)
              .where((s) => s > 0);
          if (sizes.isNotEmpty) {
            size = sizes.reduce((a, b) => a + b) / sizes.length;
          }
        }
        return (
          fontName: bestLine.fontName,
          fontSize: size,
          styles: List<PdfFontStyle>.from(bestLine.fontStyle),
        );
      }
    } catch (_) {}

    return (fontName: 'Helvetica', fontSize: 0, styles: <PdfFontStyle>[]);
  }

  PdfFontFamily _mapFontFamily(String rawName) {
    final name = rawName.toLowerCase();
    if (name.contains('times') ||
        name.contains('georgia') ||
        name.contains('garamond') ||
        name.contains('cambria') ||
        name.contains('palatino') ||
        name.contains('serif')) {
      return PdfFontFamily.timesRoman;
    }
    if (name.contains('courier') ||
        name.contains('consolas') ||
        name.contains('monaco') ||
        name.contains('mono') ||
        name.contains('menlo')) {
      return PdfFontFamily.courier;
    }
    // Arial, Helvetica, Calibri, Roboto, etc. → Helvetica (closest standard).
    return PdfFontFamily.helvetica;
  }

  Future<String> buildPdfFromImages(
    List<String> imagePaths, {
    String? outputName,
    List<String>? ocrTextPerPage,
  }) async {
    final doc = PdfDocument();
    try {
      for (var i = 0; i < imagePaths.length; i++) {
        final bytes = await File(imagePaths[i]).readAsBytes();
        final image = PdfBitmap(bytes);
        final page = doc.pages.add();
        final pageSize = page.getClientSize();
        page.graphics.drawImage(
          image,
          Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
        );

        if (ocrTextPerPage != null &&
            i < ocrTextPerPage.length &&
            ocrTextPerPage[i].trim().isNotEmpty) {
          page.graphics.setTransparency(0.01);
          page.graphics.drawString(
            ocrTextPerPage[i],
            PdfStandardFont(PdfFontFamily.helvetica, 8),
            bounds: Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
            brush: PdfBrushes.black,
          );
          page.graphics.setTransparency(1);
        }
      }
      final out = Uint8List.fromList(doc.saveSync());
      return _writeOutput(
        out,
        outputName ?? 'scan_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } finally {
      doc.dispose();
    }
  }

  Future<int> pageCount(String path) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    try {
      return doc.pages.count;
    } finally {
      doc.dispose();
    }
  }

  /// Draws freehand strokes onto a page (screen-space mapped to page bounds).
  Future<void> bakePenStrokes({
    required String path,
    required int pageOneBased,
    required Size viewSize,
    required List<({List<Offset> points, Color color, double width})> strokes,
  }) async {
    if (strokes.isEmpty || viewSize.width <= 0 || viewSize.height <= 0) return;
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    try {
      final page = doc.pages[pageOneBased - 1];
      final pageSize = page.size;
      final sx = pageSize.width / viewSize.width;
      final sy = pageSize.height / viewSize.height;
      final g = page.graphics;

      for (final stroke in strokes) {
        if (stroke.points.length < 2) continue;
        final pen = PdfPen(
          PdfColor(
            (stroke.color.r * 255.0).round().clamp(0, 255),
            (stroke.color.g * 255.0).round().clamp(0, 255),
            (stroke.color.b * 255.0).round().clamp(0, 255),
          ),
          width: stroke.width,
        );
        for (var i = 1; i < stroke.points.length; i++) {
          final a = stroke.points[i - 1];
          final b = stroke.points[i];
          g.drawLine(
            pen,
            Offset(a.dx * sx, a.dy * sy),
            Offset(b.dx * sx, b.dy * sy),
          );
        }
      }
      final bytes = Uint8List.fromList(doc.saveSync());
      await File(path).writeAsBytes(bytes, flush: true);
    } finally {
      doc.dispose();
    }
  }

  Future<String> extractText(String path, {int? pageOneBased}) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    try {
      final extractor = PdfTextExtractor(doc);
      if (pageOneBased != null) {
        return extractor.extractText(startPageIndex: pageOneBased - 1);
      }
      return extractor.extractText();
    } finally {
      doc.dispose();
    }
  }

  /// Extract editable boxes by rebuilding words → visual lines → paragraphs.
  ///
  /// Syncfusion's extractTextLines often returns mid-word fragments on
  /// complex PDFs; rebuilding from TextWords keeps full readable text.
  Future<({List<PdfEditableBox> boxes, List<PdfPageMetrics> pages})>
      extractEditableBoxes(String path) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    final uuid = const Uuid();
    try {
      final pages = <PdfPageMetrics>[
        for (var i = 0; i < doc.pages.count; i++)
          PdfPageMetrics(
            width: doc.pages[i].size.width,
            height: doc.pages[i].size.height,
          ),
      ];
      final extractor = PdfTextExtractor(doc);
      final boxes = <PdfEditableBox>[];

      for (var pageIndex = 0; pageIndex < doc.pages.count; pageIndex++) {
        final page = pages[pageIndex];
        final rawLines = extractor.extractTextLines(
          startPageIndex: pageIndex,
          endPageIndex: pageIndex,
        );

        final words = <_WordInfo>[];
        for (final line in rawLines) {
          if (line.wordCollection.isEmpty) {
            final t = line.text.replaceAll('\r', '').trim();
            if (t.isEmpty) continue;
            words.add(_WordInfo.fromLineFallback(line, t));
            continue;
          }
          for (final word in line.wordCollection) {
            final t = word.text.replaceAll('\r', '').trim();
            if (t.isEmpty) continue;
            words.add(_WordInfo.fromTextWord(word));
          }
        }

        if (words.isEmpty) continue;

        final visualLines = _clusterWordsIntoLines(words);
        final paragraphs = _groupLinesIntoParagraphs(visualLines);

        for (final paragraph in paragraphs) {
          final displayBounds = _boundsForReadableText(
            glyphBounds: paragraph.bounds,
            text: paragraph.text,
            fontSize: paragraph.fontSize,
            page: page,
          );
          boxes.add(
            PdfEditableBox(
              id: uuid.v4(),
              pageIndex: pageIndex,
              originalBounds: paragraph.bounds,
              bounds: displayBounds,
              text: paragraph.text,
              fontSize: paragraph.fontSize,
              fontName: paragraph.fontName,
              bold: paragraph.bold,
              italic: paragraph.italic,
            ),
          );
        }
      }

      return (boxes: boxes, pages: pages);
    } finally {
      doc.dispose();
    }
  }

  /// Expand a box so the full paragraph text is visible/editable.
  Rect _boundsForReadableText({
    required Rect glyphBounds,
    required String text,
    required double fontSize,
    required PdfPageMetrics page,
  }) {
    final lines = text.split('\n');
    final longest = lines.fold<int>(
      0,
      (m, l) => l.length > m ? l.length : m,
    );
    final neededW = math.max(
      glyphBounds.width,
      longest * fontSize * 0.52,
    );
    final neededH = math.max(
      glyphBounds.height,
      lines.length * fontSize * 1.35,
    );

    var left = glyphBounds.left;
    var top = glyphBounds.top;
    var width = neededW;
    var height = neededH;

    final maxRight = page.width - 8;
    final maxBottom = page.height - 8;
    if (left + width > maxRight) {
      width = math.max(40.0, maxRight - left);
    }
    if (width < neededW && left > 8) {
      left = math.max(8.0, maxRight - neededW);
      width = math.min(neededW, maxRight - left);
    }
    if (top + height > maxBottom) {
      height = math.max(fontSize * 1.35, maxBottom - top);
    }

    return Rect.fromLTWH(left, top, width, height);
  }

  /// Cluster words into visual lines by Y center, then join L→R.
  List<_LineInfo> _clusterWordsIntoLines(List<_WordInfo> words) {
    final sorted = List<_WordInfo>.from(words)
      ..sort((a, b) {
        final dy = a.bounds.center.dy.compareTo(b.bounds.center.dy);
        if (dy != 0) return dy;
        return a.bounds.left.compareTo(b.bounds.left);
      });

    final lines = <List<_WordInfo>>[];
    for (final word in sorted) {
      if (lines.isEmpty) {
        lines.add([word]);
        continue;
      }
      final current = lines.last;
      final ref = current.first;
      final yTol = math.max(
        3.0,
        math.max(ref.bounds.height, word.bounds.height) * 0.55,
      );
      if ((word.bounds.center.dy - ref.bounds.center.dy).abs() <= yTol) {
        current.add(word);
      } else {
        lines.add([word]);
      }
    }

    return [
      for (final cluster in lines) _LineInfo.fromWords(cluster),
    ];
  }

  /// Merge consecutive visual lines that belong to the same paragraph.
  List<({
    String text,
    Rect bounds,
    double fontSize,
    String fontName,
    bool bold,
    bool italic,
  })> _groupLinesIntoParagraphs(List<_LineInfo> lines) {
    final out = <({
      String text,
      Rect bounds,
      double fontSize,
      String fontName,
      bool bold,
      bool italic,
    })>[];
    if (lines.isEmpty) return out;

    var cluster = <_LineInfo>[lines.first];

    void flush() {
      if (cluster.isEmpty) return;
      var bounds = cluster.first.bounds;
      for (final l in cluster.skip(1)) {
        bounds = bounds.expandToInclude(l.bounds);
      }
      final sizes = cluster.map((l) => l.fontSize).toList()..sort();
      final fontSize = sizes[sizes.length ~/ 2];
      out.add((
        text: cluster.map((l) => l.text).join('\n'),
        bounds: bounds,
        fontSize: fontSize,
        fontName: cluster.first.fontName,
        bold: cluster.first.bold,
        italic: cluster.first.italic,
      ));
      cluster = [];
    }

    for (var i = 1; i < lines.length; i++) {
      final prev = cluster.last;
      final next = lines[i];
      final gap = next.bounds.top - prev.bounds.bottom;
      final maxH = math.max(prev.bounds.height, next.bounds.height);
      final leftDelta = (next.bounds.left - prev.bounds.left).abs();
      final hOverlap = prev.bounds
          .intersect(
            Rect.fromLTRB(
              next.bounds.left,
              prev.bounds.top,
              next.bounds.right,
              prev.bounds.bottom,
            ),
          )
          .width;
      final sameColumn = leftDelta <= math.max(18.0, prev.fontSize * 2) ||
          hOverlap > math.min(prev.bounds.width, next.bounds.width) * 0.25;
      final sizeDelta = (next.fontSize - prev.fontSize).abs();
      final similarSize =
          sizeDelta <= 1.5 || sizeDelta <= prev.fontSize * 0.22;
      final closeVertically = gap <= maxH * 1.15;

      if (closeVertically && sameColumn && similarSize) {
        cluster.add(next);
      } else {
        flush();
        cluster = [next];
      }
    }
    flush();
    return out;
  }

  /// Open a Syncfusion platform renderer session for page bitmaps.
  Future<PdfPageRenderSession> openPageRenderSession(String path) async {
    final bytes = await File(path).readAsBytes();
    final documentId = 'folio_edit_${DateTime.now().microsecondsSinceEpoch}';
    final countStr = await PdfViewerPlatform.instance.initializePdfRenderer(
      bytes,
      documentId,
    );
    final pageCount = int.tryParse(countStr ?? '') ?? 0;
    final widths = await PdfViewerPlatform.instance.getPagesWidth(documentId);
    final heights = await PdfViewerPlatform.instance.getPagesHeight(documentId);
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
  }

  /// Apply dirty / new / deleted boxes. Font size is taken from each box as-is.
  Future<String> applyEditableBoxes({
    required String path,
    required List<PdfEditableBox> boxes,
    Color coverColor = const Color(0xFFFFFFFF),
  }) async {
    final toWrite = boxes.where((b) => b.needsSave).toList(growable: false);
    if (toWrite.isEmpty) {
      throw ArgumentError('No text changes to save.');
    }

    // Stable paint order: top→bottom so neighbors don't randomly stack.
    toWrite.sort((a, b) {
      final p = a.pageIndex.compareTo(b.pageIndex);
      if (p != 0) return p;
      return a.bounds.top.compareTo(b.bounds.top);
    });

    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    try {
      final coverBrush = PdfSolidBrush(
        PdfColor(
          (coverColor.r * 255.0).round().clamp(0, 255),
          (coverColor.g * 255.0).round().clamp(0, 255),
          (coverColor.b * 255.0).round().clamp(0, 255),
        ),
      );
      final brush = PdfSolidBrush(PdfColor(28, 28, 30));

      for (final box in toWrite) {
        if (box.pageIndex < 0 || box.pageIndex >= doc.pages.count) continue;
        final g = doc.pages[box.pageIndex].graphics;

        // Erase only the original paragraph so neighbors stay intact.
        if (!box.isNew) {
          final padded = Rect.fromLTRB(
            box.originalBounds.left - 0.6,
            box.originalBounds.top - 0.6,
            box.originalBounds.right + 0.8,
            box.originalBounds.bottom + 0.8,
          );
          g.drawRectangle(bounds: padded, brush: coverBrush);
        } else if (box.deleted) {
          // nothing to cover
        }

        if (box.deleted || box.text.trim().isEmpty) continue;

        // Sticky size — never derive from box height.
        final fontSize = box.fontSize.clamp(6.0, 96.0);
        final styles = <PdfFontStyle>[
          if (box.bold) PdfFontStyle.bold,
          if (box.italic) PdfFontStyle.italic,
        ];
        final font = PdfStandardFont(
          _mapFontFamily(box.fontName),
          fontSize,
          multiStyle: styles,
        );

        // Draw into the original glyph area when present so edits stay in
        // the paragraph slot and don't cover neighbors. New boxes use bounds.
        final drawBounds = box.isNew
            ? Rect.fromLTWH(
                box.bounds.left,
                box.bounds.top,
                math.max(box.bounds.width, 4),
                math.max(box.bounds.height, fontSize * 1.2),
              )
            : Rect.fromLTWH(
                box.originalBounds.left,
                box.originalBounds.top,
                math.max(box.originalBounds.width, 4),
                math.max(box.originalBounds.height, fontSize * 1.2),
              );

        final format = PdfStringFormat(
          alignment: PdfTextAlignment.left,
          lineAlignment: PdfVerticalAlignment.top,
          wordWrap: PdfWordWrapType.word,
        )
          ..lineLimit = true
          ..noClip = false;

        g.drawString(
          box.text,
          font,
          bounds: drawBounds,
          brush: brush,
          format: format,
        );
      }

      final outBytes = Uint8List.fromList(doc.saveSync());
      return _writeOutput(
        outBytes,
        '${p.basenameWithoutExtension(path)}_edited.pdf',
      );
    } finally {
      doc.dispose();
    }
  }

  Future<Directory> _exportsDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'folio_exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> _writeOutput(Uint8List bytes, String fileName) async {
    final dir = await _exportsDir();
    final out = File(p.join(dir.path, fileName));
    await out.writeAsBytes(bytes, flush: true);
    return out.path;
  }
}

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

  Future<ui.Image?> renderPage(int pageIndex, {double maxWidth = 1080}) async {
    if (pageIndex < 0 || pageIndex >= pageCount) return null;
    final pageW = widths[pageIndex];
    final pageH = heights[pageIndex];
    if (pageW <= 0 || pageH <= 0) return null;

    final scale = math.min(1.0, maxWidth / pageW);
    final width = math.max(1, (pageW * scale).round());
    final height = math.max(1, (pageH * scale).round());

    final pixels = await PdfViewerPlatform.instance.getPage(
      pageIndex + 1,
      width,
      height,
      documentId,
    );
    if (pixels == null || pixels.isEmpty) return null;

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  Future<void> close() async {
    await PdfViewerPlatform.instance.closeDocument(documentId);
  }
}

class _WordInfo {
  _WordInfo({
    required this.text,
    required this.bounds,
    required this.fontSize,
    required this.fontName,
    required this.bold,
    required this.italic,
  });

  final String text;
  final Rect bounds;
  final double fontSize;
  final String fontName;
  final bool bold;
  final bool italic;

  factory _WordInfo.fromTextWord(TextWord word) {
    final size = word.fontSize > 0
        ? word.fontSize
        : (word.bounds.height * 0.75).clamp(8.0, 48.0);
    final styles = List<PdfFontStyle>.from(word.fontStyle);
    return _WordInfo(
      text: word.text,
      bounds: word.bounds,
      fontSize: size,
      fontName: word.fontName.isEmpty ? 'Helvetica' : word.fontName,
      bold: styles.contains(PdfFontStyle.bold),
      italic: styles.contains(PdfFontStyle.italic),
    );
  }

  factory _WordInfo.fromLineFallback(TextLine line, String text) {
    final size = line.fontSize > 0
        ? line.fontSize
        : (line.bounds.height * 0.75).clamp(8.0, 48.0);
    final styles = List<PdfFontStyle>.from(line.fontStyle);
    return _WordInfo(
      text: text,
      bounds: line.bounds,
      fontSize: size,
      fontName: line.fontName.isEmpty ? 'Helvetica' : line.fontName,
      bold: styles.contains(PdfFontStyle.bold),
      italic: styles.contains(PdfFontStyle.italic),
    );
  }
}

class _LineInfo {
  _LineInfo({
    required this.text,
    required this.bounds,
    required this.fontSize,
    required this.fontName,
    required this.bold,
    required this.italic,
  });

  final String text;
  final Rect bounds;
  final double fontSize;
  final String fontName;
  final bool bold;
  final bool italic;

  /// Join words on one visual line L→R, merging adjacent fragments.
  factory _LineInfo.fromWords(List<_WordInfo> words) {
    final sorted = List<_WordInfo>.from(words)
      ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

    final parts = <String>[];
    var bounds = sorted.first.bounds;
    final sizes = <double>[];
    for (var i = 0; i < sorted.length; i++) {
      final w = sorted[i];
      bounds = bounds.expandToInclude(w.bounds);
      sizes.add(w.fontSize);
      if (i == 0) {
        parts.add(w.text);
        continue;
      }
      final prev = sorted[i - 1];
      final gap = w.bounds.left - prev.bounds.right;
      // Touching / overlapping fragments → one word (no space).
      if (gap <= math.max(1.0, prev.fontSize * 0.22)) {
        parts[parts.length - 1] = '${parts.last}${w.text}';
      } else {
        parts.add(w.text);
      }
    }
    sizes.sort();
    return _LineInfo(
      text: parts.join(' '),
      bounds: bounds,
      fontSize: sizes[sizes.length ~/ 2],
      fontName: sorted.first.fontName,
      bold: sorted.first.bold,
      italic: sorted.first.italic,
    );
  }
}
