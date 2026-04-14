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

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'pagePaths': pagePaths,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DocumentDraft.fromMap(Map<String, dynamic> map) {
    return DocumentDraft(
      id: map['id'] as String,
      name: map['name'] as String,
      pagePaths: List<String>.from(map['pagePaths'] as List<dynamic>),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
