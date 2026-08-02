import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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
  Future<String> replaceTextOnPage({
    required String path,
    required int pageIndexZeroBased,
    required Rect bounds,
    required String newText,
    Color coverColor = const Color(0xFFFFFFFF),
    double fontSize = 12,
  }) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    try {
      final page = doc.pages[pageIndexZeroBased];
      final g = page.graphics;
      g.drawRectangle(
        bounds: bounds,
        brush: PdfSolidBrush(
          PdfColor(
            (coverColor.r * 255.0).round().clamp(0, 255),
            (coverColor.g * 255.0).round().clamp(0, 255),
            (coverColor.b * 255.0).round().clamp(0, 255),
          ),
        ),
      );
      g.drawString(
        newText,
        PdfStandardFont(PdfFontFamily.helvetica, fontSize),
        bounds: bounds,
        brush: PdfSolidBrush(PdfColor(28, 28, 30)),
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
