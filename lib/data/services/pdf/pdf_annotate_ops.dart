import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfAnnotateOps {
  static Future<void> bakePenStrokes({
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

  static Future<String> extractText(String path, {int? pageOneBased}) async {
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
}
