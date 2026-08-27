import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../features/reader/editable_text_box.dart';
import 'pdf_io.dart';

/// Draws user-added text boxes onto a PDF. Does not rewrite existing text.
class PdfEditOps {
  static Future<String> applyAddedText({
    required String path,
    required List<PdfEditableBox> boxes,
  }) async {
    final toWrite = boxes
        .where((b) => b.isNew && !b.deleted && b.text.trim().isNotEmpty)
        .toList(growable: false);
    if (toWrite.isEmpty) {
      throw ArgumentError('No text to save.');
    }

    final fileBytes = await File(path).readAsBytes();
    final doc = PdfDocument(inputBytes: fileBytes);

    try {
      for (final box in toWrite) {
        if (box.pageIndex < 0 || box.pageIndex >= doc.pages.count) continue;
        final g = doc.pages[box.pageIndex].graphics;
        final fontSize = box.fontSize.clamp(6.0, 96.0);
        final font = PdfStandardFont(
          PdfFontFamily.helvetica,
          fontSize,
          style: box.bold
              ? PdfFontStyle.bold
              : box.italic
                  ? PdfFontStyle.italic
                  : PdfFontStyle.regular,
        );
        final format = PdfStringFormat(
          alignment: PdfTextAlignment.left,
          lineAlignment: PdfVerticalAlignment.top,
          wordWrap: PdfWordWrapType.word,
        )
          ..lineLimit = true
          ..noClip = false;

        final slot = box.bounds;
        final c = box.color;
        final brush = PdfSolidBrush(
          PdfColor(
            (c.r * 255.0).round().clamp(0, 255),
            (c.g * 255.0).round().clamp(0, 255),
            (c.b * 255.0).round().clamp(0, 255),
          ),
        );
        g.drawString(
          box.text,
          font,
          bounds: Rect.fromLTWH(
            slot.left,
            slot.top,
            math.max(slot.width, 8),
            math.max(slot.height, 4),
          ),
          brush: brush,
          format: format,
        );
      }

      final outBytes = Uint8List.fromList(doc.saveSync());
      return PdfIo.writeOutput(
        outBytes,
        '${p.basenameWithoutExtension(path)}_text.pdf',
      );
    } finally {
      doc.dispose();
    }
  }
}
