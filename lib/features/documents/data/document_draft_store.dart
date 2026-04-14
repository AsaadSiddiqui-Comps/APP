import 'package:flutter/foundation.dart';

import '../models/document_draft.dart';

class DocumentDraftStore extends ChangeNotifier {
  DocumentDraftStore._();

  static final DocumentDraftStore instance = DocumentDraftStore._();

  final List<DocumentDraft> _drafts = <DocumentDraft>[];

  List<DocumentDraft> get drafts => List<DocumentDraft>.unmodifiable(_drafts);

  DocumentDraft? findById(String id) {
    for (final DocumentDraft draft in _drafts) {
      if (draft.id == id) {
        return draft;
      }
    }
    return null;
  }

  void upsert(DocumentDraft draft) {
    final int index = _drafts.indexWhere((DocumentDraft d) => d.id == draft.id);
    if (index == -1) {
      _drafts.insert(0, draft);
    } else {
      _drafts[index] = draft;
      _drafts.sort(
        (DocumentDraft a, DocumentDraft b) =>
            b.updatedAt.compareTo(a.updatedAt),
      );
    }
    notifyListeners();
  }
}
