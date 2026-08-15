import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'pdf_ops_service.dart';

class ScanResult {
  const ScanResult({
    required this.path,
    required this.ocrEnabled,
    required this.ocrWordCount,
  });

  final String path;
  final bool ocrEnabled;
  final int ocrWordCount;
}

class ScanService {
  ScanService(this._pdfOps);

  final PdfOpsService _pdfOps;

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<ScanResult?> scanToPdf({bool runOcr = true}) async {
    if (!isSupported) {
      throw UnsupportedError(
        'Document scanning is available on Android and iOS.',
      );
    }

    final options = DocumentScannerOptions(
      documentFormat: DocumentFormat.jpeg,
      mode: ScannerMode.filter,
      pageLimit: 30,
      isGalleryImport: true,
    );

    final scanner = DocumentScanner(options: options);
    try {
      final result = await scanner.scanDocument();
      final images = result.images;
      if (images.isEmpty) return null;

      List<List<OcrSpan>>? ocrWords;
      var wordCount = 0;
      if (runOcr) {
        ocrWords = await _recognizeAll(images);
        wordCount = ocrWords.fold<int>(0, (n, page) => n + page.length);
      }

      final path = await _pdfOps.buildPdfFromImages(
        images,
        ocrWordsPerPage: ocrWords,
      );
      return ScanResult(
        path: path,
        ocrEnabled: runOcr,
        ocrWordCount: wordCount,
      );
    } on PlatformException catch (e) {
      if (_isUserCancel(e)) return null;
      rethrow;
    } finally {
      await scanner.close();
    }
  }

  bool _isUserCancel(PlatformException e) {
    final blob = '${e.code} ${e.message}'.toLowerCase();
    return blob.contains('cancel') || blob.contains('canceled');
  }

  Future<List<List<OcrSpan>>> _recognizeAll(List<String> imagePaths) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final pages = <List<OcrSpan>>[];
    try {
      for (final path in imagePaths) {
        final input = InputImage.fromFilePath(path);
        final result = await recognizer.processImage(input);
        final spans = <OcrSpan>[];
        for (final block in result.blocks) {
          for (final line in block.lines) {
            for (final element in line.elements) {
              final text = element.text.trim();
              if (text.isEmpty) continue;
              spans.add(OcrSpan(text: text, bounds: element.boundingBox));
            }
          }
        }
        pages.add(spans);
      }
    } finally {
      await recognizer.close();
    }
    return pages;
  }
}
