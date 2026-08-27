import 'package:flutter/material.dart';

/// One OCR word (or token) in image-pixel coordinates.
class OcrSpan {
  const OcrSpan({required this.text, required this.bounds});

  final String text;
  final Rect bounds;
}
