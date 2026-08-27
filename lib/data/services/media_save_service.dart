import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Saves images into the system gallery without broad storage permissions.
///
/// Android 10+: MediaStore (Pictures/Folio). No WRITE_EXTERNAL_STORAGE.
/// iOS: Photos add-only (NSPhotoLibraryAddUsageDescription).
class MediaSaveService {
  static const _channel = MethodChannel('folio/save_images');

  Future<int> saveImagesToGallery(List<String> paths) async {
    if (kIsWeb || paths.isEmpty) return 0;
    if (!(Platform.isAndroid || Platform.isIOS)) return 0;
    final existing = <String>[
      for (final path in paths)
        if (await File(path).exists()) path,
    ];
    if (existing.isEmpty) return 0;
    try {
      final saved = await _channel.invokeMethod<int>(
        'saveImages',
        {'paths': existing},
      );
      return saved ?? 0;
    } on PlatformException catch (e) {
      debugPrint('saveImagesToGallery failed: ${e.code} ${e.message}');
      return 0;
    }
  }
}
