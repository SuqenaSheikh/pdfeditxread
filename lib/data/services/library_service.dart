import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/pdf_document_item.dart';
import '../repositories/library_repository.dart';
import 'pdf_ops_service.dart';

class LibraryService {
  LibraryService(this._repo, this._pdfOps);

  final LibraryRepository _repo;
  final PdfOpsService _pdfOps;
  final _uuid = const Uuid();

  List<PdfDocumentItem> all() => _repo.getAll();
  List<PdfDocumentItem> recents() => _repo.getRecents();
  List<PdfDocumentItem> favorites() => _repo.getFavorites();

  Future<PdfDocumentItem?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final path = picked.path;
    if (path == null) return null;
    return importFromPath(path, displayName: picked.name);
  }

  Future<List<PdfDocumentItem>> pickMultiple() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
    );
    if (result == null) return const [];
    final items = <PdfDocumentItem>[];
    for (final file in result.files) {
      if (file.path == null) continue;
      final item = await importFromPath(file.path!, displayName: file.name);
      items.add(item);
    }
    return items;
  }

  Future<PdfDocumentItem> importFromPath(
    String sourcePath, {
    String? displayName,
  }) async {
    final existing = _repo.getAll().where((e) => e.path == sourcePath);
    if (existing.isNotEmpty) {
      final item = existing.first.copyWith(lastOpenedAt: DateTime.now());
      await _repo.upsert(item);
      return item;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final libraryDir = Directory(p.join(docsDir.path, 'folio_library'));
    if (!await libraryDir.exists()) {
      await libraryDir.create(recursive: true);
    }

    final name = displayName ?? p.basename(sourcePath);
    final id = _uuid.v4();
    final destPath = p.join(libraryDir.path, '$id.pdf');
    await File(sourcePath).copy(destPath);

    int? pages;
    int? size;
    try {
      pages = await _pdfOps.pageCount(destPath);
      size = await File(destPath).length();
    } catch (_) {}

    final item = PdfDocumentItem(
      id: id,
      path: destPath,
      name: name.endsWith('.pdf') ? name : '$name.pdf',
      addedAt: DateTime.now(),
      lastOpenedAt: DateTime.now(),
      pageCount: pages,
      fileSizeBytes: size,
    );
    await _repo.upsert(item);
    return item;
  }

  Future<void> markOpened(PdfDocumentItem item, {int? page}) async {
    await _repo.upsert(
      item.copyWith(
        lastOpenedAt: DateTime.now(),
        lastPage: page ?? item.lastPage,
      ),
    );
  }

  Future<void> toggleFavorite(PdfDocumentItem item) async {
    await _repo.upsert(item.copyWith(isFavorite: !item.isFavorite));
  }

  Future<void> remove(PdfDocumentItem item) async {
    await _repo.remove(item.id);
    try {
      final file = File(item.path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> rename(PdfDocumentItem item, String newName) async {
    final name = newName.endsWith('.pdf') ? newName : '$newName.pdf';
    await _repo.upsert(item.copyWith(name: name));
  }

  Future<void> share(PdfDocumentItem item) async {
    await Share.shareXFiles(
      [XFile(item.path, mimeType: 'application/pdf', name: item.name)],
      subject: item.name,
    );
  }

  /// Saves a copy through the system Files UI (SAF / iOS document picker).
  /// No broad storage permission is required.
  ///
  /// Returns `true` when the user picked a destination, `false` if cancelled.
  Future<bool> downloadToDevice(PdfDocumentItem item) async {
    final file = File(item.path);
    if (!await file.exists()) {
      throw StateError('This file is no longer on this device.');
    }
    final bytes = await file.readAsBytes();
    var fileName = item.name.trim();
    if (fileName.isEmpty) fileName = 'document.pdf';
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      fileName = '$fileName.pdf';
    }

    try {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );
      return savedPath != null;
    } catch (_) {
      // If the save sheet is unavailable, fall back to the share sheet
      // (also no extra storage permission).
      await Share.shareXFiles(
        [XFile(item.path, mimeType: 'application/pdf', name: fileName)],
        subject: fileName,
      );
      return true;
    }
  }

  Future<void> sharePath(String path, {String? name}) async {
    await Share.shareXFiles(
      [
        XFile(
          path,
          mimeType: path.endsWith('.pdf')
              ? 'application/pdf'
              : 'application/octet-stream',
          name: name ?? p.basename(path),
        ),
      ],
    );
  }

  List<PageBookmark> bookmarks(String documentId) =>
      _repo.bookmarksFor(documentId);

  Future<void> togglePageBookmark({
    required String documentId,
    required int pageNumber,
    String? label,
  }) async {
    if (_repo.hasBookmark(documentId, pageNumber)) {
      await _repo.removeBookmark(documentId, pageNumber);
    } else {
      await _repo.addBookmark(
        PageBookmark(
          id: _uuid.v4(),
          documentId: documentId,
          pageNumber: pageNumber,
          createdAt: DateTime.now(),
          label: label,
        ),
      );
    }
  }

  bool hasPageBookmark(String documentId, int pageNumber) =>
      _repo.hasBookmark(documentId, pageNumber);
}
