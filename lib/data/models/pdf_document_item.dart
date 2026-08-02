class PdfDocumentItem {
  const PdfDocumentItem({
    required this.id,
    required this.path,
    required this.name,
    required this.addedAt,
    this.lastOpenedAt,
    this.pageCount,
    this.thumbnailPath,
    this.lastPage = 1,
    this.isFavorite = false,
    this.fileSizeBytes,
  });

  final String id;
  final String path;
  final String name;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final int? pageCount;
  final String? thumbnailPath;
  final int lastPage;
  final bool isFavorite;
  final int? fileSizeBytes;

  PdfDocumentItem copyWith({
    String? id,
    String? path,
    String? name,
    DateTime? addedAt,
    DateTime? lastOpenedAt,
    int? pageCount,
    String? thumbnailPath,
    int? lastPage,
    bool? isFavorite,
    int? fileSizeBytes,
  }) {
    return PdfDocumentItem(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      addedAt: addedAt ?? this.addedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      pageCount: pageCount ?? this.pageCount,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      lastPage: lastPage ?? this.lastPage,
      isFavorite: isFavorite ?? this.isFavorite,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'path': path,
        'name': name,
        'addedAt': addedAt.toIso8601String(),
        'lastOpenedAt': lastOpenedAt?.toIso8601String(),
        'pageCount': pageCount,
        'thumbnailPath': thumbnailPath,
        'lastPage': lastPage,
        'isFavorite': isFavorite,
        'fileSizeBytes': fileSizeBytes,
      };

  factory PdfDocumentItem.fromMap(Map<dynamic, dynamic> map) {
    return PdfDocumentItem(
      id: map['id'] as String,
      path: map['path'] as String,
      name: map['name'] as String,
      addedAt: DateTime.parse(map['addedAt'] as String),
      lastOpenedAt: map['lastOpenedAt'] != null
          ? DateTime.parse(map['lastOpenedAt'] as String)
          : null,
      pageCount: map['pageCount'] as int?,
      thumbnailPath: map['thumbnailPath'] as String?,
      lastPage: (map['lastPage'] as int?) ?? 1,
      isFavorite: (map['isFavorite'] as bool?) ?? false,
      fileSizeBytes: map['fileSizeBytes'] as int?,
    );
  }
}

class PageBookmark {
  const PageBookmark({
    required this.id,
    required this.documentId,
    required this.pageNumber,
    required this.createdAt,
    this.label,
  });

  final String id;
  final String documentId;
  final int pageNumber;
  final DateTime createdAt;
  final String? label;

  Map<String, dynamic> toMap() => {
        'id': id,
        'documentId': documentId,
        'pageNumber': pageNumber,
        'createdAt': createdAt.toIso8601String(),
        'label': label,
      };

  factory PageBookmark.fromMap(Map<dynamic, dynamic> map) {
    return PageBookmark(
      id: map['id'] as String,
      documentId: map['documentId'] as String,
      pageNumber: map['pageNumber'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      label: map['label'] as String?,
    );
  }
}
