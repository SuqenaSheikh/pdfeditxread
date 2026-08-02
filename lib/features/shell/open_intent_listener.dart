import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/open_intent_service.dart';
import '../../providers/app_providers.dart';
import '../reader/reader_screen.dart';

final openIntentServiceProvider = Provider<OpenIntentService>((ref) {
  return OpenIntentService();
});

class OpenIntentListener extends ConsumerStatefulWidget {
  const OpenIntentListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OpenIntentListener> createState() => _OpenIntentListenerState();
}

class _OpenIntentListenerState extends ConsumerState<OpenIntentListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final service = ref.read(openIntentServiceProvider);
    service.onPdfOpened = _openPath;
    await service.init();
    final initial = await service.takeInitialPdf();
    if (initial != null) await _openPath(initial);
  }

  Future<void> _openPath(String path) async {
    final item = await ref.read(libraryProvider.notifier).importPath(path);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderScreen(document: item)),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
