import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A user-added text box on a PDF page.
class PdfEditableBox {
  PdfEditableBox({
    required this.id,
    required this.pageIndex,
    required Rect bounds,
    required String text,
    required double fontSize,
    this.fontName = 'Helvetica',
    bool bold = false,
    bool italic = false,
    Color color = const Color(0xFF1C1C1E),
  })  : _bounds = bounds,
        _text = text,
        _fontSize = fontSize.clamp(6.0, 96.0),
        _bold = bold,
        _italic = italic,
        _color = color;

  final String id;
  final int pageIndex;
  final String fontName;
  final bool isNew = true;

  Rect _bounds;
  String _text;
  double _fontSize;
  bool _bold;
  bool _italic;
  Color _color;
  bool deleted = false;

  Rect get bounds => _bounds;
  set bounds(Rect value) {
    if (_bounds == value) return;
    _bounds = value;
  }

  String get text => _text;
  set text(String value) {
    if (_text == value) return;
    _text = value;
  }

  double get fontSize => _fontSize;

  void setFontSizeFromToolbar(double value) {
    final next = value.clamp(6.0, 96.0);
    if (_fontSize == next) return;
    _fontSize = next;
  }

  bool get bold => _bold;
  set bold(bool value) {
    if (_bold == value) return;
    _bold = value;
  }

  bool get italic => _italic;
  set italic(bool value) {
    if (_italic == value) return;
    _italic = value;
  }

  Color get color => _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
  }

  bool get needsSave => !deleted && text.trim().isNotEmpty;

  bool get dirty => needsSave;

  double get displayFontSize => fontSize.clamp(6.0, 96.0);
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
