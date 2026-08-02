import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../providers/app_providers.dart';

Future<void> _withLoading(
  BuildContext context,
  Future<void> Function() action,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
    ),
  );
  try {
    await action();
  } finally {
    if (context.mounted) Navigator.of(context).pop();
  }
}

Future<String?> _pickSinglePdf() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
  );
  return result?.files.single.path;
}

Future<List<String>> _pickMultiplePdfs() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    allowMultiple: true,
  );
  if (result == null) return const [];
  return result.files
      .map((f) => f.path)
      .whereType<String>()
      .toList(growable: false);
}

Future<void> _finishWithImport(
  BuildContext context,
  WidgetRef ref,
  String path, {
  String? name,
}) async {
  HapticFeedback.mediumImpact();
  final item = await ref.read(libraryProvider.notifier).importPath(
        path,
        name: name ?? p.basename(path),
      );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Saved to library as ${item.name}')),
  );
}

Future<void> runMergeFlow(BuildContext context, WidgetRef ref) async {
  final paths = await _pickMultiplePdfs();
  if (paths.length < 2) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least two PDFs to merge.')),
      );
    }
    return;
  }

  await _withLoading(context, () async {
    final out = await ref.read(pdfOpsServiceProvider).merge(paths);
    if (!context.mounted) return;
    await _finishWithImport(context, ref, out, name: 'Merged.pdf');
  });
}

Future<void> runSplitFlow(BuildContext context, WidgetRef ref) async {
  final path = await _pickSinglePdf();
  if (path == null || !context.mounted) return;

  final pageCount = await ref.read(pdfOpsServiceProvider).pageCount(path);
  final startCtrl = TextEditingController(text: '1');
  final endCtrl = TextEditingController(text: '$pageCount');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Split by page range'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('This file has $pageCount pages.'),
          const SizedBox(height: 12),
          TextField(
            controller: startCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'From page'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: endCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'To page'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Split'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;
  final start = int.tryParse(startCtrl.text) ?? 1;
  final end = int.tryParse(endCtrl.text) ?? pageCount;

  await _withLoading(context, () async {
    final outs = await ref.read(pdfOpsServiceProvider).split(
      path,
      ranges: [(start, end)],
    );
    if (!context.mounted || outs.isEmpty) return;
    await _finishWithImport(context, ref, outs.first);
  });
}

Future<void> runReorderFlow(BuildContext context, WidgetRef ref) async {
  final path = await _pickSinglePdf();
  if (path == null || !context.mounted) return;
  final count = await ref.read(pdfOpsServiceProvider).pageCount(path);
  var order = List<int>.generate(count, (i) => i + 1);

  final confirmed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => _ReorderPagesScreen(
        initialOrder: order,
        onChanged: (next) => order = next,
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;

  await _withLoading(context, () async {
    final out = await ref.read(pdfOpsServiceProvider).reorder(path, order);
    if (!context.mounted) return;
    await _finishWithImport(context, ref, out);
  });
}

Future<void> runDeletePagesFlow(BuildContext context, WidgetRef ref) async {
  final path = await _pickSinglePdf();
  if (path == null || !context.mounted) return;
  final count = await ref.read(pdfOpsServiceProvider).pageCount(path);
  final controller = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete pages'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('File has $count pages. Enter page numbers to remove, separated by commas (example: 2, 5, 7).'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '2, 5, 7'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final pages = controller.text
      .split(RegExp(r'[,\s]+'))
      .map(int.tryParse)
      .whereType<int>()
      .toList();
  if (pages.isEmpty) return;

  await _withLoading(context, () async {
    final out = await ref.read(pdfOpsServiceProvider).deletePages(path, pages);
    if (!context.mounted) return;
    await _finishWithImport(context, ref, out);
  });
}

Future<void> runPasswordFlow(BuildContext context, WidgetRef ref) async {
  final path = await _pickSinglePdf();
  if (path == null || !context.mounted) return;
  final controller = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Set a password'),
      content: TextField(
        controller: controller,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Password'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Protect'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final password = controller.text;
  if (password.isEmpty) return;

  await _withLoading(context, () async {
    final out = await ref.read(pdfOpsServiceProvider).protectWithPassword(
          path,
          userPassword: password,
        );
    if (!context.mounted) return;
    await _finishWithImport(context, ref, out);
  });
}

Future<void> runExportImagesFlow(BuildContext context, WidgetRef ref) async {
  final path = await _pickSinglePdf();
  if (path == null || !context.mounted) return;

  final format = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Export as PNG'),
            onTap: () => Navigator.pop(ctx, 'png'),
          ),
          ListTile(
            title: const Text('Export as JPEG'),
            onTap: () => Navigator.pop(ctx, 'jpg'),
          ),
        ],
      ),
    ),
  );
  if (format == null || !context.mounted) return;

  await _withLoading(context, () async {
    final outs = await ref.read(pdfOpsServiceProvider).exportPagesAsImages(
          path,
          format: format,
        );
    if (!context.mounted) return;
    HapticFeedback.mediumImpact();
    if (outs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images were exported.')),
      );
      return;
    }
    await ref.read(libraryServiceProvider).sharePath(outs.first);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${outs.length} image(s).')),
    );
  });
}

class _ReorderPagesScreen extends StatefulWidget {
  const _ReorderPagesScreen({
    required this.initialOrder,
    required this.onChanged,
  });

  final List<int> initialOrder;
  final ValueChanged<List<int>> onChanged;

  @override
  State<_ReorderPagesScreen> createState() => _ReorderPagesScreenState();
}

class _ReorderPagesScreenState extends State<_ReorderPagesScreen> {
  late List<int> _order;

  @override
  void initState() {
    super.initState();
    _order = [...widget.initialOrder];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder pages'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onChanged(_order);
              Navigator.pop(context, true);
            },
            child: const Text('Done'),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _order.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _order.removeAt(oldIndex);
            _order.insert(newIndex, item);
            widget.onChanged(_order);
          });
        },
        itemBuilder: (context, index) {
          final page = _order[index];
          return Card(
            key: ValueKey('page-$page-$index'),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                foregroundColor: Theme.of(context).colorScheme.primary,
                child: Text('$page'),
              ),
              title: Text('Page $page'),
              trailing: const Icon(Icons.drag_handle),
            ),
          );
        },
      ),
    );
  }
}
