import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'pdf_ops_service.dart';

class ScanService {
  ScanService(this._pdfOps);

  final PdfOpsService _pdfOps;

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<String?> scanToPdf({bool runOcr = true}) async {
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

      List<String>? ocrText;
      if (runOcr) {
        ocrText = await _recognizeAll(images);
      }

      return _pdfOps.buildPdfFromImages(
        images,
        ocrTextPerPage: ocrText,
      );
    } finally {
      await scanner.close();
    }
  }

  Future<List<String>> _recognizeAll(List<String> imagePaths) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final texts = <String>[];
    try {
      for (final path in imagePaths) {
        final input = InputImage.fromFilePath(path);
        final result = await recognizer.processImage(input);
        texts.add(result.text);
      }
    } finally {
      await recognizer.close();
    }
    return texts;
  }
}
