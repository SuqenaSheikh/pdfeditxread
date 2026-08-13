import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// One editable text region on a PDF page (Canva-style overlay).
///
/// [fontSize] / [lockedFontSize] are captured once from the PDF text layer.
/// Typing must never change size — only the +/- toolbar does.
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
       lockedFontSize = fontSize.clamp(6.0, 96.0),
       originalText = text,
       originalBold = bold,
       originalItalic = italic;

  final String id;
  final int pageIndex;

  /// Fixed cover rect used when saving — never grows across re-edits.
  final Rect originalBounds;

  /// Exact text at extraction — used so Save only writes real edits.
  final String originalText;
  final bool originalBold;
  final bool originalItalic;

  /// Size captured at extraction.
  final double lockedFontSize;

  Rect _bounds;
  String _text;
  double _fontSize;
  bool _bold;
  bool _italic;

  final String fontName;
  final bool isNew;

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

  /// Only call from the font-size toolbar. Text edits must not call this.
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

  /// True only when the user actually changed this box (not the whole page).
  bool get needsSave {
    if (isNew) return !deleted && text.trim().isNotEmpty;
    if (deleted) return true;
    if (text != originalText) return true;
    if (bold != originalBold || italic != originalItalic) return true;
    if ((fontSize - lockedFontSize).abs() > 0.01) return true;
    if ((bounds.left - originalBounds.left).abs() > 1.5) return true;
    if ((bounds.top - originalBounds.top).abs() > 1.5) return true;
    if ((bounds.width - originalBounds.width).abs() > 3) return true;
    if ((bounds.height - originalBounds.height).abs() > 3) return true;
    return false;
  }

  /// UI helper: show “unsaved” chrome for this box.
  bool get dirty => needsSave;

  /// Font size that visually fits [originalBounds] — never larger than the PDF slot.
  /// Used for on-screen editing AND for save, so text cannot grow on select/save.
  double fontSizeFittingSlot() {
    final slot = isNew ? bounds : originalBounds;
    final rawLines = text.split('\n');
    // Estimate wrap: ~0.5em average char width in the slot.
    final avgChar = math.max(lockedFontSize * 0.5, 1.0);
    final cols = math.max(1, (slot.width / avgChar).floor());
    var wrapped = 0;
    for (final line in rawLines) {
      if (line.isEmpty) {
        wrapped += 1;
        continue;
      }
      wrapped += math.max(1, (line.length / cols).ceil());
    }
    wrapped = wrapped.clamp(1, 80);
    final fromHeight = slot.height / wrapped / 1.15;
    // Never exceed the extracted size — only shrink to fit the slot.
    return math.min(lockedFontSize, fromHeight).clamp(6.0, lockedFontSize);
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
