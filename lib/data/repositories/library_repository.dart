import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/pdf_document_item.dart';

class LibraryRepository {
  LibraryRepository(this._libraryBox, this._bookmarkBox);

  final Box _libraryBox;
  final Box _bookmarkBox;

  static Future<LibraryRepository> open() async {
    final library = await Hive.openBox(AppConstants.hiveBoxLibrary);
    final bookmarks = await Hive.openBox(AppConstants.hiveBoxBookmarks);
    return LibraryRepository(library, bookmarks);
  }

  List<PdfDocumentItem> getAll() {
    return _libraryBox.values
        .whereType<Map>()
        .map(PdfDocumentItem.fromMap)
        .toList()
      ..sort((a, b) {
        final aTime = a.lastOpenedAt ?? a.addedAt;
        final bTime = b.lastOpenedAt ?? b.addedAt;
        return bTime.compareTo(aTime);
      });
  }

  List<PdfDocumentItem> getRecents({int limit = 30}) {
    final items = getAll().where((e) => e.lastOpenedAt != null).toList()
      ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
    if (items.length <= limit) return items;
    return items.take(limit).toList();
  }

  List<PdfDocumentItem> getFavorites() {
    return getAll().where((e) => e.isFavorite).toList();
  }

  PdfDocumentItem? getById(String id) {
    final raw = _libraryBox.get(id);
    if (raw is Map) return PdfDocumentItem.fromMap(raw);
    return null;
  }

  Future<void> upsert(PdfDocumentItem item) async {
    await _libraryBox.put(item.id, item.toMap());
  }

  Future<void> remove(String id) async {
    await _libraryBox.delete(id);
    final keys = _bookmarkBox.keys
        .where((k) => k.toString().startsWith('$id::'))
        .toList();
    for (final key in keys) {
      await _bookmarkBox.delete(key);
    }
  }

  List<PageBookmark> bookmarksFor(String documentId) {
    return _bookmarkBox.values
        .whereType<Map>()
        .map(PageBookmark.fromMap)
        .where((b) => b.documentId == documentId)
        .toList()
      ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
  }

  Future<void> addBookmark(PageBookmark bookmark) async {
    await _bookmarkBox.put(
      '${bookmark.documentId}::${bookmark.pageNumber}',
      bookmark.toMap(),
    );
  }

  Future<void> removeBookmark(String documentId, int pageNumber) async {
    await _bookmarkBox.delete('$documentId::$pageNumber');
  }

  bool hasBookmark(String documentId, int pageNumber) {
    return _bookmarkBox.containsKey('$documentId::$pageNumber');
  }
}
