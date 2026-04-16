class DocumentDraft {
  const DocumentDraft({
    required this.id,
    required this.name,
    required this.pagePaths,
    required this.filterBasePaths,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> pagePaths;
  final List<String> filterBasePaths;
  final DateTime updatedAt;

  String get thumbnailPath => pagePaths.isNotEmpty ? pagePaths.first : '';

  DocumentDraft copyWith({
    String? id,
    String? name,
    List<String>? pagePaths,
    List<String>? filterBasePaths,
    DateTime? updatedAt,
  }) {
    return DocumentDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      pagePaths: pagePaths ?? this.pagePaths,
      filterBasePaths: filterBasePaths ?? this.filterBasePaths,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'pagePaths': pagePaths,
      'filterBasePaths': filterBasePaths,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DocumentDraft.fromMap(Map<String, dynamic> map) {
    final List<String> pages = List<String>.from(
      map['pagePaths'] as List<dynamic>,
    );
    final List<String> filterBases =
        (map['filterBasePaths'] as List<dynamic>?)
            ?.map((dynamic e) => e.toString())
            .toList(growable: false) ??
        List<String>.from(pages);

    return DocumentDraft(
      id: map['id'] as String,
      name: map['name'] as String,
      pagePaths: pages,
      filterBasePaths: filterBases,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
