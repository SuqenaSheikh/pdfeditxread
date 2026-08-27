import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'ocr_span.dart';
import 'pdf_io.dart';
import 'pdf_page_render_session.dart';

class PdfScanOps {
  static Future<List<String>> exportPagesAsImages(
    String path, {
    required String format,
    int quality = 90,
  }) async {
    final session = await PdfPageRenderSession.open(path);
    final outputs = <String>[];
    final base = p.basenameWithoutExtension(path);
    final dir = await PdfIo.exportsDir();
    final ext = format.toLowerCase() == 'jpg' ? 'jpg' : 'png';

    try {
      for (var i = 0; i < session.pageCount; i++) {
        final image = await session.renderPage(i, maxWidth: 1600);
        if (image == null) continue;
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (byteData == null) continue;

        var bytes = byteData.buffer.asUint8List();
        final outPath = p.join(dir.path, '${base}_page${i + 1}.$ext');

        if (ext == 'jpg') {
          final compressed = await FlutterImageCompress.compressWithList(
            bytes,
            format: CompressFormat.jpeg,
            quality: quality,
          );
          bytes = Uint8List.fromList(compressed);
        }
        await File(outPath).writeAsBytes(bytes, flush: true);
        outputs.add(outPath);
      }
    } finally {
      await session.close();
    }
    if (outputs.isEmpty) {
      throw StateError('Could not render pages from this PDF.');
    }
    return outputs;
  }

  static Future<String> buildPdfFromImages(
    List<String> imagePaths, {
    String? outputName,
    List<List<OcrSpan>>? ocrWordsPerPage,
  }) async {
    final fontCache = <int, PdfStandardFont>{};

    PdfFont fontFor(double size) {
      final key = math.max(4, size.round());
      return fontCache.putIfAbsent(
        key,
        () => PdfStandardFont(PdfFontFamily.helvetica, key.toDouble()),
      );
    }

    final doc = PdfDocument();
    doc.pageSettings.margins.all = 0;
    try {
      for (var i = 0; i < imagePaths.length; i++) {
        final bytes = await File(imagePaths[i]).readAsBytes();
        final image = PdfBitmap(bytes);
        const maxWidth = 595.0;
        final pageW = maxWidth;
        final pageH = maxWidth * image.height / math.max(image.width, 1);
        doc.pageSettings.size = Size(pageW, pageH);
        final page = doc.pages.add();
        final pageSize = page.getClientSize();

        final ocr = (ocrWordsPerPage != null && i < ocrWordsPerPage.length)
            ? ocrWordsPerPage[i]
            : const <OcrSpan>[];
        if (ocr.isNotEmpty) {
          final sx = pageSize.width / image.width;
          final sy = pageSize.height / image.height;
          final format = PdfStringFormat(
            alignment: PdfTextAlignment.left,
            lineAlignment: PdfVerticalAlignment.middle,
            wordWrap: PdfWordWrapType.none,
          )
            ..lineLimit = false
            ..noClip = true;
          for (final span in ocr) {
            final bounds = Rect.fromLTWH(
              span.bounds.left * sx,
              span.bounds.top * sy,
              math.max(span.bounds.width * sx, 2),
              math.max(span.bounds.height * sy, 4),
            );
            page.graphics.drawString(
              span.text,
              fontFor(bounds.height * 0.92),
              bounds: bounds,
              brush: PdfBrushes.black,
              format: format,
            );
          }
        }

        page.graphics.drawImage(
          image,
          Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
        );
      }
      final out = Uint8List.fromList(doc.saveSync());
      return PdfIo.writeOutput(
        out,
        outputName ?? 'scan_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } finally {
      doc.dispose();
    }
  }
}
