import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Catalog of fonts discovered in a PDF — embedded TrueType + standard 14.
///
/// Used so edited text is redrawn with the same face the page already uses,
/// instead of collapsing everything to Helvetica.
class PdfEmbeddedFontCatalog {
  PdfEmbeddedFontCatalog._(this._ttfByKey);

  /// PostScript / BaseFont key (lowercased, subset prefix stripped) → TTF/OTF bytes.
  final Map<String, Uint8List> _ttfByKey;

  /// Flutter [FontLoader] family names already registered this session.
  final Map<String, String> _flutterFamilies = {};

  static final RegExp _subsetPrefix = RegExp(r'^[A-Z]{6}\+');

  /// Build a catalog by scanning [pdfBytes] for FontFile2 / FontFile3 streams.
  factory PdfEmbeddedFontCatalog.fromPdfBytes(Uint8List pdfBytes) {
    final byKey = <String, Uint8List>{};

    // Index: objectNumber → uncompressed stream bytes for FontFile* objects.
    final fontStreams = <int, Uint8List>{};
    final objPattern = RegExp(
      r'(\d+)\s+0\s+obj\b',
      multiLine: true,
    );
    final dataStr = latin1.decode(pdfBytes, allowInvalid: true);

    for (final match in objPattern.allMatches(dataStr)) {
      final objNum = int.parse(match.group(1)!);
      final objStart = match.end;
      final endObj = dataStr.indexOf('endobj', objStart);
      if (endObj < 0) continue;
      final objSlice = dataStr.substring(objStart, endObj);
      if (!objSlice.contains('/FontFile2') &&
          !objSlice.contains('/FontFile3') &&
          !objSlice.contains('stream')) {
        // Still may be a FontFile2 target object (just a stream).
      }

      final streamIdx = objSlice.indexOf('stream');
      final endStream = objSlice.lastIndexOf('endstream');
      if (streamIdx < 0 || endStream < streamIdx) continue;

      // Only index objects that look like font programs (have Length /Filter
      // typical of FontFile2) — or are referenced as FontFile2 later.
      final header = objSlice.substring(0, streamIdx);
      final isFontProgram = header.contains('/Length') &&
          (header.contains('/Filter') ||
              header.contains('/Subtype') ||
              header.contains('/Length1'));

      var streamStart = streamIdx + 'stream'.length;
      if (streamStart < objSlice.length && objSlice[streamStart] == '\r') {
        streamStart++;
      }
      if (streamStart < objSlice.length && objSlice[streamStart] == '\n') {
        streamStart++;
      }
      final streamLatin = objSlice.substring(streamStart, endStream);
      final streamBytes = Uint8List.fromList(latin1.encode(streamLatin));

      Uint8List? raw;
      if (header.contains('/FlateDecode') || header.contains('/Fl')) {
        try {
          raw = Uint8List.fromList(zlib.decode(streamBytes));
        } catch (_) {
          try {
            raw = Uint8List.fromList(
              zlib.decode(Uint8List.sublistView(streamBytes)),
            );
          } catch (_) {
            continue;
          }
        }
      } else {
        raw = streamBytes;
      }

      if (raw.length < 4) continue;
      final sig = raw[0] << 24 | raw[1] << 16 | raw[2] << 8 | raw[3];
      final isTtf = sig == 0x00010000 ||
          (raw[0] == 0x4F && raw[1] == 0x54 && raw[2] == 0x54 && raw[3] == 0x4F) ||
          (raw[0] == 0x74 && raw[1] == 0x72 && raw[2] == 0x75 && raw[3] == 0x65);
      // Keep candidates; FontFile2 refs decide which are fonts. Also keep
      // stream objects that look like TTF/OTF.
      if (isTtf || isFontProgram) {
        fontStreams[objNum] = raw;
      }
    }

    // Map BaseFont / FontName → FontFile2|3 object number.
    final fileRefPattern = RegExp(
      r'/Font(?:Name|BaseFont)\s*/([^\s/\[\(<>]+).*?/FontFile[23]\s+(\d+)\s+\d+\s+R'
      r'|/FontFile[23]\s+(\d+)\s+\d+\s+R.*?/Font(?:Name|BaseFont)\s*/([^\s/\[\(<>]+)',
      dotAll: true,
    );
    for (final m in fileRefPattern.allMatches(dataStr)) {
      final name = m.group(1) ?? m.group(4);
      final objStr = m.group(2) ?? m.group(3);
      if (name == null || objStr == null) continue;
      final objNum = int.tryParse(objStr);
      if (objNum == null) continue;
      final bytes = fontStreams[objNum];
      if (bytes == null) continue;
      for (final key in _keysForPdfName(name)) {
        byKey.putIfAbsent(key, () => bytes);
      }
    }

    // Fallback: any /FontFile2 N 0 R — index stream by TTF PostScript name.
    final looseRefs = RegExp(r'/FontFile[23]\s+(\d+)\s+\d+\s+R');
    for (final m in looseRefs.allMatches(dataStr)) {
      final objNum = int.tryParse(m.group(1)!);
      if (objNum == null) continue;
      final bytes = fontStreams[objNum];
      if (bytes == null) continue;
      for (final key in _ttfNameKeys(bytes)) {
        byKey.putIfAbsent(key, () => bytes);
      }
      // Also scan nearby BaseFont within 800 chars before the ref.
      final start = (m.start - 800).clamp(0, dataStr.length);
      final window = dataStr.substring(start, m.end);
      for (final bm in RegExp(r'/BaseFont\s*/([^\s/\[\(<>]+)').allMatches(window)) {
        for (final key in _keysForPdfName(bm.group(1)!)) {
          byKey.putIfAbsent(key, () => bytes);
        }
      }
      for (final bm
          in RegExp(r'/FontName\s*/([^\s/\[\(<>]+)').allMatches(window)) {
        for (final key in _keysForPdfName(bm.group(1)!)) {
          byKey.putIfAbsent(key, () => bytes);
        }
      }
    }

    return PdfEmbeddedFontCatalog._(byKey);
  }

  static List<String> _keysForPdfName(String raw) {
    var name = raw.trim();
    name = name.replaceFirst(_subsetPrefix, '');
    final keys = <String>{normalizeKey(name)};
    // Times-Roman → timesroman, times, times-roman
    keys.add(normalizeKey(name.replaceAll('-', '')));
    keys.add(normalizeKey(name.split('-').first));
    return keys.toList();
  }

  static String normalizeKey(String name) =>
      name.replaceFirst(_subsetPrefix, '').toLowerCase().trim();

  /// Read name IDs 1/4/6 from a TTF/OTF name table.
  static List<String> _ttfNameKeys(Uint8List data) {
    final keys = <String>{};
    if (data.length < 12) return const [];
    final bd = ByteData.sublistView(data);
    final numTables = bd.getUint16(4);
    var nameOffset = -1;
    for (var i = 0; i < numTables; i++) {
      final o = 12 + i * 16;
      if (o + 16 > data.length) break;
      final tag = String.fromCharCodes(data.sublist(o, o + 4));
      if (tag == 'name') {
        nameOffset = bd.getUint32(o + 8);
        break;
      }
    }
    if (nameOffset < 0 || nameOffset + 6 > data.length) return const [];
    final count = bd.getUint16(nameOffset + 2);
    final storage = nameOffset + bd.getUint16(nameOffset + 4);
    for (var i = 0; i < count; i++) {
      final rec = nameOffset + 6 + i * 12;
      if (rec + 12 > data.length) break;
      final platform = bd.getUint16(rec);
      final nameId = bd.getUint16(rec + 6);
      final length = bd.getUint16(rec + 8);
      final offset = bd.getUint16(rec + 10);
      if (nameId != 1 && nameId != 4 && nameId != 6) continue;
      final start = storage + offset;
      final end = start + length;
      if (end > data.length) continue;
      final raw = data.sublist(start, end);
      String text;
      try {
        text = (platform == 0 || platform == 3)
            ? utf16Be(raw)
            : latin1.decode(raw, allowInvalid: true);
      } catch (_) {
        continue;
      }
      text = text.trim();
      if (text.isEmpty) continue;
      for (final k in _keysForPdfName(text.replaceAll(' ', ''))) {
        keys.add(k);
      }
      keys.add(normalizeKey(text));
      keys.add(normalizeKey(text.replaceAll(' ', '')));
    }
    return keys.toList();
  }

  static String utf16Be(List<int> raw) {
    final out = StringBuffer();
    for (var i = 0; i + 1 < raw.length; i += 2) {
      out.writeCharCode((raw[i] << 8) | raw[i + 1]);
    }
    return out.toString();
  }

  bool get isEmpty => _ttfByKey.isEmpty;
  int get embeddedCount => _ttfByKey.length;

  /// Register embedded faces with Flutter so edit overlays can match.
  Future<void> ensureFlutterFontsLoaded() async {
    for (final entry in _ttfByKey.entries) {
      if (_flutterFamilies.containsKey(entry.key)) continue;
      final family = 'FolioPdf_${entry.key.replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
      try {
        final loader = FontLoader(family);
        loader.addFont(
          Future.value(ByteData.sublistView(entry.value)),
        );
        await loader.load();
        _flutterFamilies[entry.key] = family;
      } catch (_) {
        // Corrupt/subset stream — fall back to standard UI fonts.
      }
    }
  }

  /// Flutter fontFamily for overlays, or null to use a platform fallback.
  String? flutterFamilyFor(String pdfFontName, {bool bold = false}) {
    for (final key in _lookupKeys(pdfFontName, bold: bold, italic: false)) {
      final fam = _flutterFamilies[key];
      if (fam != null) return fam;
    }
    for (final key in _lookupKeys(pdfFontName, bold: false, italic: false)) {
      final fam = _flutterFamilies[key];
      if (fam != null) return fam;
    }
    return null;
  }

  /// Build a Syncfusion [PdfFont] matching [fontName] as closely as possible.
  PdfFont resolvePdfFont({
    required String fontName,
    required double size,
    bool bold = false,
    bool italic = false,
  }) {
    final faceIsBold = _nameImpliesBold(fontName) || bold;
    final faceIsItalic = _nameImpliesItalic(fontName) || italic;

    for (final key in _lookupKeys(
      fontName,
      bold: faceIsBold,
      italic: faceIsItalic,
    )) {
      final bytes = _ttfByKey[key];
      if (bytes == null) continue;
      // Already on a Bold/Italic face — don't force synthetic emboldening
      // (that warped DejaVu metrics into spaced-out "3 0 0").
      final synthetic = <PdfFontStyle>[
        if (faceIsBold && !_keyImpliesBold(key) && !_nameImpliesBold(fontName))
          PdfFontStyle.bold,
        if (faceIsItalic &&
            !_keyImpliesItalic(key) &&
            !_nameImpliesItalic(fontName))
          PdfFontStyle.italic,
      ];
      try {
        return PdfTrueTypeFont(
          bytes,
          size,
          multiStyle: synthetic,
        );
      } catch (_) {
        continue;
      }
    }

    return _standardFallback(
      fontName,
      size: size,
      bold: faceIsBold,
      italic: faceIsItalic,
    );
  }

  List<String> _lookupKeys(
    String fontName, {
    required bool bold,
    required bool italic,
  }) {
    final base = normalizeKey(fontName.replaceFirst(_subsetPrefix, ''));
    final cleaned = base
        .replaceAll('bolditalic', '')
        .replaceAll('boldoblique', '')
        .replaceAll('italic', '')
        .replaceAll('oblique', '')
        .replaceAll('bold', '')
        .replaceAll(RegExp(r'[-_]+'), '')
        .trim();
    final keys = <String>[];

    void add(String k) {
      if (k.isNotEmpty && !keys.contains(k)) keys.add(k);
    }

    if (bold && italic) {
      add('$cleaned-bolditalic');
      add('${cleaned}bolditalic');
      add('$base-bolditalic');
    }
    if (bold) {
      add('${cleaned}bold');
      add('$cleaned-bold');
      add('${base}bold');
      add(normalizeKey('$fontName-Bold'));
    }
    if (italic) {
      add('${cleaned}italic');
      add('$cleaned-italic');
      add('${cleaned}oblique');
    }
    add(base);
    add(cleaned);
    add(normalizeKey(fontName.split('-').first));
    // Common DejaVu / Liberation style PS names.
    if (cleaned.contains('dejavusans')) {
      add(bold ? 'dejavusans-bold' : 'dejavusans');
      add(bold ? 'dejavusansbold' : 'dejavusans');
    }
    return keys;
  }

  static bool _nameImpliesBold(String name) {
    final n = name.toLowerCase();
    return n.contains('bold') || n.contains('black') || n.contains('heavy');
  }

  static bool _nameImpliesItalic(String name) {
    final n = name.toLowerCase();
    return n.contains('italic') || n.contains('oblique');
  }

  static bool _keyImpliesBold(String key) =>
      key.contains('bold') || key.contains('black');

  static bool _keyImpliesItalic(String key) =>
      key.contains('italic') || key.contains('oblique');

  PdfFont _standardFallback(
    String fontName, {
    required double size,
    required bool bold,
    required bool italic,
  }) {
    final family = mapStandardFamily(fontName);
    final styles = <PdfFontStyle>[
      if (bold) PdfFontStyle.bold,
      if (italic) PdfFontStyle.italic,
    ];
    return PdfStandardFont(
      family,
      size,
      multiStyle: styles,
    );
  }

  /// Map PDF BaseFont names to the standard 14 families.
  static PdfFontFamily mapStandardFamily(String rawName) {
    final name = normalizeKey(rawName);
    if (name.contains('times') ||
        name.contains('georgia') ||
        name.contains('garamond') ||
        name.contains('cambria') ||
        name.contains('palatino') ||
        name.contains('liberation serif') ||
        name.contains('liberationserif') ||
        name.contains('nimbusrom') ||
        name.contains('serif')) {
      return PdfFontFamily.timesRoman;
    }
    if (name.contains('courier') ||
        name.contains('consolas') ||
        name.contains('monaco') ||
        name.contains('mono') ||
        name.contains('menlo') ||
        name.contains('liberation mono')) {
      return PdfFontFamily.courier;
    }
    if (name.contains('symbol')) return PdfFontFamily.symbol;
    if (name.contains('zapf') || name.contains('dingbat')) {
      return PdfFontFamily.zapfDingbats;
    }
    // Helvetica cluster (Arial, DejaVu→TTF preferred, Calibri, etc.)
    return PdfFontFamily.helvetica;
  }

  /// UI fallback when no embedded face was registered.
  static String? flutterFallbackFamily(String pdfFontName) {
    final family = mapStandardFamily(pdfFontName);
    switch (family) {
      case PdfFontFamily.timesRoman:
        return 'Times New Roman';
      case PdfFontFamily.courier:
        return 'Courier New';
      case PdfFontFamily.helvetica:
      default:
        return 'Roboto';
    }
  }
}
