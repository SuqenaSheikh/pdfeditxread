import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../features/reader/editable_text_box.dart';
import 'pdf/ocr_span.dart';
import 'pdf/pdf_annotate_ops.dart';
import 'pdf/pdf_edit_ops.dart';
import 'pdf/pdf_page_ops.dart';
import 'pdf/pdf_page_render_session.dart';
import 'pdf/pdf_scan_ops.dart';

export 'pdf/ocr_span.dart';
export 'pdf/pdf_page_render_session.dart';

/// Structural PDF operations (merge, split, reorder, delete, encrypt, export).
class PdfOpsService {
  Future<String> merge(List<String> paths, {String? outputName}) =>
      PdfPageOps.merge(paths, outputName: outputName);

  Future<List<String>> split(
    String path, {
    required List<(int start, int end)> ranges,
  }) =>
      PdfPageOps.split(path, ranges: ranges);

  Future<String> reorder(String path, List<int> newOrderOneBased) {
    return PdfPageOps.extractPages(
      path,
      newOrderOneBased,
      outputName: '${p.basenameWithoutExtension(path)}_reordered.pdf',
    );
  }

  Future<String> extractPages(
    String path,
    List<int> pagesOneBased, {
    String? outputName,
  }) =>
      PdfPageOps.extractPages(path, pagesOneBased, outputName: outputName);

  Future<List<String>> splitSelectedAndRest(
    String path,
    List<int> selectedOneBased,
  ) =>
      PdfPageOps.splitSelectedAndRest(path, selectedOneBased);

  Future<String> deletePages(String path, List<int> pagesOneBased) =>
      PdfPageOps.deletePages(path, pagesOneBased);

  Future<String> protectWithPassword(
    String path, {
    required String userPassword,
  }) =>
      PdfPageOps.protectWithPassword(path, userPassword: userPassword);

  Future<int> pageCount(String path) => PdfPageOps.pageCount(path);

  Future<List<String>> exportPagesAsImages(
    String path, {
    required String format,
    int quality = 90,
  }) =>
      PdfScanOps.exportPagesAsImages(path, format: format, quality: quality);

  Future<String> buildPdfFromImages(
    List<String> imagePaths, {
    String? outputName,
    List<List<OcrSpan>>? ocrWordsPerPage,
  }) =>
      PdfScanOps.buildPdfFromImages(
        imagePaths,
        outputName: outputName,
        ocrWordsPerPage: ocrWordsPerPage,
      );

  Future<void> bakePenStrokes({
    required String path,
    required int pageOneBased,
    required Size viewSize,
    required List<({List<Offset> points, Color color, double width})> strokes,
  }) =>
      PdfAnnotateOps.bakePenStrokes(
        path: path,
        pageOneBased: pageOneBased,
        viewSize: viewSize,
        strokes: strokes,
      );

  Future<String> extractText(String path, {int? pageOneBased}) =>
      PdfAnnotateOps.extractText(path, pageOneBased: pageOneBased);

  Future<List<PdfPageMetrics>> pageMetrics(String path) =>
      PdfPageOps.pageMetrics(path);

  Future<String> applyAddedText({
    required String path,
    required List<PdfEditableBox> boxes,
  }) =>
      PdfEditOps.applyAddedText(path: path, boxes: boxes);

  Future<PdfPageRenderSession> openPageRenderSession(String path) =>
      PdfPageRenderSession.open(path);
}
