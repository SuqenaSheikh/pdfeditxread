import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/widgets/folio_password_field.dart';
import '../../data/models/pdf_document_item.dart';
import '../../data/services/media_save_service.dart';
import '../../providers/app_providers.dart';
import 'export_images_result_sheet.dart';
import 'merge_order_screen.dart';
import 'page_select_tool_screen.dart';
import 'reorder_pages_screen.dart';
import 'tool_pdf_picker_screen.dart';

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

Future<List<PdfDocumentItem>?> _pickFromLibrary(
  BuildContext context, {
  required String title,
  bool allowMultiple = false,
  int minSelection = 1,
}) {
  return Navigator.of(context).push<List<PdfDocumentItem>>(
    MaterialPageRoute(
      builder: (_) => ToolPdfPickerScreen(
        title: title,
        allowMultiple: allowMultiple,
        minSelection: minSelection,
      ),
    ),
  );
}

Future<void> runMergeFlow(BuildContext context, WidgetRef ref) async {
  final picked = await _pickFromLibrary(
    context,
    title: 'Merge PDFs',
    allowMultiple: true,
    minSelection: 2,
  );
  if (picked == null || picked.length < 2 || !context.mounted) return;

  final ordered = await Navigator.of(context).push<List<PdfDocumentItem>>(
    MaterialPageRoute(
      builder: (_) => MergeOrderScreen(documents: picked),
    ),
  );
  if (ordered == null || ordered.length < 2 || !context.mounted) return;

  await _withLoading(context, () async {
    final out = await ref.read(pdfOpsServiceProvider).merge(
          ordered.map((d) => d.path).toList(),
        );
    if (!context.mounted) return;
    await _finishWithImport(context, ref, out, name: 'Merged.pdf');
  });
}

Future<void> runSplitFlow(BuildContext context, WidgetRef ref) async {
  final picked = await _pickFromLibrary(context, title: 'Split PDF');
  if (picked == null || picked.isEmpty || !context.mounted) return;
  final doc = picked.first;

  final count = doc.pageCount ??
      await ref.read(pdfOpsServiceProvider).pageCount(doc.path);
  if (!context.mounted) return;
  if (count < 2) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Need at least 2 pages to split.')),
    );
    return;
  }

  final selected = await Navigator.of(context).push<List<int>>(
    MaterialPageRoute(
      builder: (_) => PageSelectToolScreen(
        document: doc,
        pageCount: count,
        mode: PageSelectMode.split,
      ),
    ),
  );
  if (selected == null || selected.isEmpty || !context.mounted) return;

  await _withLoading(context, () async {
    final outs = await ref.read(pdfOpsServiceProvider).splitSelectedAndRest(
          doc.path,
          selected,
        );
    if (!context.mounted || outs.isEmpty) return;
    for (final out in outs) {
      if (!context.mounted) return;
      await _finishWithImport(context, ref, out);
    }
  });
}

Future<void> runReorderFlow(BuildContext context, WidgetRef ref) async {
  final picked = await _pickFromLibrary(context, title: 'Reorder pages');
  if (picked == null || picked.isEmpty || !context.mounted) return;
  final doc = picked.first;

  final count = doc.pageCount ??
      await ref.read(pdfOpsServiceProvider).pageCount(doc.path);
  if (!context.mounted) return;
  if (count < 1) return;

  final order = await Navigator.of(context).push<List<int>>(
    MaterialPageRoute(
      builder: (_) => ReorderPagesScreen(
        document: doc,
        pageCount: count,
      ),
    ),
  );
  if (order == null || !context.mounted) return;

  await _withLoading(context, () async {
    final out = await ref.read(pdfOpsServiceProvider).reorder(doc.path, order);
    if (!context.mounted) return;
    await _finishWithImport(context, ref, out);
  });
}

Future<void> runDeletePagesFlow(BuildContext context, WidgetRef ref) async {
  final picked = await _pickFromLibrary(context, title: 'Delete pages');
  if (picked == null || picked.isEmpty || !context.mounted) return;
  final doc = picked.first;

  final count = doc.pageCount ??
      await ref.read(pdfOpsServiceProvider).pageCount(doc.path);
  if (!context.mounted) return;
  if (count < 2) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Need at least 2 pages to delete some.')),
    );
    return;
  }

  final pages = await Navigator.of(context).push<List<int>>(
    MaterialPageRoute(
      builder: (_) => PageSelectToolScreen(
        document: doc,
        pageCount: count,
        mode: PageSelectMode.delete,
      ),
    ),
  );
  if (pages == null || pages.isEmpty || !context.mounted) return;

  await _withLoading(context, () async {
    final out =
        await ref.read(pdfOpsServiceProvider).deletePages(doc.path, pages);
    if (!context.mounted) return;
    await _finishWithImport(context, ref, out);
  });
}

Future<void> runPasswordFlow(BuildContext context, WidgetRef ref) async {
  final path = await _pickSinglePdf();
  if (path == null || !context.mounted) return;

  final password = await showFolioPasswordDialog(
    context,
    title: 'Set a password',
    message: 'Choose a password to encrypt this PDF. Keep it somewhere safe.',
    confirmLabel: 'Protect',
  );
  if (password == null || password.isEmpty || !context.mounted) return;

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

  List<String> outs = const [];
  var savedToGallery = 0;
  try {
    await _withLoading(context, () async {
      outs = await ref.read(pdfOpsServiceProvider).exportPagesAsImages(
            path,
            format: format,
          );
      if (outs.isEmpty) return;
      savedToGallery = await MediaSaveService().saveImagesToGallery(outs);
    });
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not export images: $e')),
    );
    return;
  }
  if (!context.mounted) return;
  HapticFeedback.mediumImpact();
  if (outs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No images were exported.')),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => ExportImagesResultSheet(
      paths: outs,
      savedToGallery: savedToGallery >= outs.length,
    ),
  );
}
