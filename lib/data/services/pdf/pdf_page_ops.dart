import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf_io.dart';
import '../../../features/reader/editable_text_box.dart';

class PdfPageOps {
  static Future<String> merge(List<String> paths, {String? outputName}) async {
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
      return PdfIo.writeOutput(
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

  static Future<List<String>> split(
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
        outputs.add(await PdfIo.writeOutput(bytes, '${base}_part${r + 1}.pdf'));
      } finally {
        target.dispose();
        source.dispose();
      }
    }
    return outputs;
  }

  static Future<String> extractPages(
    String path,
    List<int> pagesOneBased, {
    String? outputName,
  }) async {
    if (pagesOneBased.isEmpty) {
      throw ArgumentError('Select at least one page.');
    }
    final source = PdfDocument(inputBytes: await File(path).readAsBytes());
    final target = PdfDocument();
    try {
      for (final pageNum in pagesOneBased) {
        if (pageNum < 1 || pageNum > source.pages.count) continue;
        final template = source.pages[pageNum - 1].createTemplate();
        target.pages.add().graphics.drawPdfTemplate(
              template,
              Offset.zero,
              Size(template.size.width, template.size.height),
            );
      }
      if (target.pages.count == 0) {
        throw ArgumentError('No valid pages to extract.');
      }
      final bytes = Uint8List.fromList(target.saveSync());
      return PdfIo.writeOutput(
        bytes,
        outputName ??
            '${p.basenameWithoutExtension(path)}_part_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } finally {
      target.dispose();
      source.dispose();
    }
  }

  static Future<List<String>> splitSelectedAndRest(
    String path,
    List<int> selectedOneBased,
  ) async {
    final count = await pageCount(path);
    final selected = selectedOneBased
        .where((p) => p >= 1 && p <= count)
        .toSet()
        .toList()
      ..sort();
    if (selected.isEmpty || selected.length == count) {
      throw ArgumentError(
        'Select some pages — but not all — to split into two PDFs.',
      );
    }
    final rest = [
      for (var i = 1; i <= count; i++)
        if (!selected.contains(i)) i,
    ];
    final base = p.basenameWithoutExtension(path);
    final first = await extractPages(
      path,
      selected,
      outputName: '${base}_part1.pdf',
    );
    final second = await extractPages(
      path,
      rest,
      outputName: '${base}_part2.pdf',
    );
    return [first, second];
  }

  static Future<String> deletePages(String path, List<int> pagesOneBased) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    try {
      final sorted = [...pagesOneBased]..sort((a, b) => b.compareTo(a));
      for (final page in sorted) {
        if (page >= 1 && page <= doc.pages.count) {
          doc.pages.removeAt(page - 1);
        }
      }
      final bytes = Uint8List.fromList(doc.saveSync());
      return PdfIo.writeOutput(
        bytes,
        '${p.basenameWithoutExtension(path)}_edited.pdf',
      );
    } finally {
      doc.dispose();
    }
  }

  static Future<String> protectWithPassword(
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
      return PdfIo.writeOutput(
        bytes,
        '${p.basenameWithoutExtension(path)}_protected.pdf',
      );
    } finally {
      doc.dispose();
    }
  }

  static Future<int> pageCount(String path) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    try {
      return doc.pages.count;
    } finally {
      doc.dispose();
    }
  }

  static Future<List<PdfPageMetrics>> pageMetrics(String path) async {
    final doc = PdfDocument(inputBytes: await File(path).readAsBytes());
    try {
      return [
        for (var i = 0; i < doc.pages.count; i++)
          PdfPageMetrics(
            width: doc.pages[i].size.width,
            height: doc.pages[i].size.height,
          ),
      ];
    } finally {
      doc.dispose();
    }
  }
}
