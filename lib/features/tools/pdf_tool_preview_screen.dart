import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Full-document preview used from tool flows (merge order, etc.).
class PdfToolPreviewScreen extends StatelessWidget {
  const PdfToolPreviewScreen({
    super.key,
    required this.path,
    required this.title,
  });

  final String path;
  final String title;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: Text(title)),
      body: SfPdfViewerTheme(
        data: SfPdfViewerThemeData(backgroundColor: bg),
        child: SfPdfViewer.file(
          File(path),
          canShowPasswordDialog: true,
          enableTextSelection: false,
          canShowScrollHead: true,
        ),
      ),
    );
  }
}
