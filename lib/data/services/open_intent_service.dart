import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef OpenPdfCallback = void Function(String path);

/// Bridges Android VIEW/SEND PDF intents into Dart (FR-1).
class OpenIntentService {
  OpenIntentService();

  static const _channel = MethodChannel('folio/open_pdf');
  OpenPdfCallback? onPdfOpened;

  Future<void> init() async {
    if (kIsWeb) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOpenPdf' && call.arguments is String) {
        onPdfOpened?.call(call.arguments as String);
      }
    });
  }

  Future<String?> takeInitialPdf() async {
    if (kIsWeb) return null;
    try {
      final path = await _channel.invokeMethod<String>('getInitialPdf');
      return path;
    } catch (_) {
      return null;
    }
  }
}
