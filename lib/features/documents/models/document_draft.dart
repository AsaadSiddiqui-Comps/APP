class DocumentDraft {
  const DocumentDraft({
    required this.id,
    required this.name,
    required this.pagePaths,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> pagePaths;
  final DateTime updatedAt;

  String get thumbnailPath => pagePaths.isNotEmpty ? pagePaths.first : '';

  DocumentDraft copyWith({
    String? id,
    String? name,
    List<String>? pagePaths,
    DateTime? updatedAt,
  }) {
    return DocumentDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      pagePaths: pagePaths ?? this.pagePaths,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
