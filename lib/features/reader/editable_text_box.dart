import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// One editable text region on a PDF page (Canva-style overlay).
///
/// [fontSize] is captured once from the PDF text layer. Edits to the string
/// must never change it — only the explicit +/- toolbar controls do.
class PdfEditableBox {
  PdfEditableBox({
    required this.id,
    required this.pageIndex,
    required this.originalBounds,
    required Rect bounds,
    required String text,
    required double fontSize,
    required this.fontName,
    bool bold = false,
    bool italic = false,
    this.isNew = false,
  }) : _bounds = bounds,
       _text = text,
       _fontSize = fontSize.clamp(6.0, 96.0),
       _bold = bold,
       _italic = italic,
       lockedFontSize = fontSize.clamp(6.0, 96.0);

  final String id;
  final int pageIndex;

  /// Fixed cover rect used when saving — never grows across re-edits.
  final Rect originalBounds;

  /// Size captured at extraction (reference only).
  final double lockedFontSize;

  Rect _bounds;
  String _text;
  double _fontSize;
  bool _bold;
  bool _italic;

  final String fontName;
  final bool isNew;

  bool deleted = false;
  bool dirty = false;

  Rect get bounds => _bounds;
  set bounds(Rect value) {
    if (_bounds == value) return;
    _bounds = value;
    dirty = true;
  }

  String get text => _text;
  set text(String value) {
    if (_text == value) return;
    _text = value;
    dirty = true;
  }

  double get fontSize => _fontSize;

  /// Only call from the font-size toolbar. Text edits must not call this.
  void setFontSizeFromToolbar(double value) {
    final next = value.clamp(6.0, 96.0);
    if (_fontSize == next) return;
    _fontSize = next;
    dirty = true;
  }

  bool get bold => _bold;
  set bold(bool value) {
    if (_bold == value) return;
    _bold = value;
    dirty = true;
  }

  bool get italic => _italic;
  set italic(bool value) {
    if (_italic == value) return;
    _italic = value;
    dirty = true;
  }

  bool get needsSave =>
      deleted || dirty || (isNew && !deleted && text.trim().isNotEmpty);

  /// Grow height to fit [text] at the current font size; width stays fixed.
  /// Does not change [fontSize].
  void fitHeightToText({double lineHeightFactor = 1.25}) {
    final avgCharW = math.max(fontSize * 0.5, 1.0);
    final cols = math.max(1, (bounds.width / avgCharW).floor());
    final wrappedLines = text.split('\n').fold<int>(0, (sum, line) {
      if (line.isEmpty) return sum + 1;
      return sum + math.max(1, (line.length / cols).ceil());
    });
    final needed =
        math.max(1, wrappedLines) * fontSize * lineHeightFactor;
    final minH = fontSize * lineHeightFactor;
    final height = math.max(needed, minH);
    if ((height - bounds.height).abs() > 0.5) {
      bounds = Rect.fromLTWH(
        bounds.left,
        bounds.top,
        bounds.width,
        height,
      );
    }
  }
}

@immutable
class PdfPageMetrics {
  const PdfPageMetrics({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;
}
