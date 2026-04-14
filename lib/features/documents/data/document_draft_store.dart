import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'document_storage_service.dart';
import '../models/document_draft.dart';

class DocumentDraftStore extends ChangeNotifier {
  DocumentDraftStore._();

  static final DocumentDraftStore instance = DocumentDraftStore._();

  final List<DocumentDraft> _drafts = <DocumentDraft>[];
  bool _initialized = false;

  List<DocumentDraft> get drafts => List<DocumentDraft>.unmodifiable(_drafts);

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await DocumentStorageService.instance.ensureDirectories();
    await _loadFromDisk();
    _initialized = true;
    notifyListeners();
  }

  DocumentDraft? findById(String id) {
    for (final DocumentDraft draft in _drafts) {
      if (draft.id == id) {
        return draft;
      }
    }
    return null;
  }

  Future<void> upsert(DocumentDraft draft) async {
    await initialize();

    final int index = _drafts.indexWhere((DocumentDraft d) => d.id == draft.id);
    if (index == -1) {
      _drafts.insert(0, draft);
    } else {
      _drafts[index] = draft;
    }

    _drafts.sort(
      (DocumentDraft a, DocumentDraft b) => b.updatedAt.compareTo(a.updatedAt),
    );
    await _saveToDisk();
    notifyListeners();
  }

  Future<void> _loadFromDisk() async {
    final File file = await _draftsIndexFile();
    if (!await file.exists()) {
      return;
    }

    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return;
    }

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    _drafts
      ..clear()
      ..addAll(
        decoded
            .whereType<Map<String, dynamic>>()
            .map(DocumentDraft.fromMap)
            .toList(growable: false),
      );

    _drafts.sort(
      (DocumentDraft a, DocumentDraft b) => b.updatedAt.compareTo(a.updatedAt),
    );
  }

  Future<void> _saveToDisk() async {
    final File file = await _draftsIndexFile();
    final List<Map<String, dynamic>> encoded = _drafts
        .map((DocumentDraft draft) => draft.toMap())
        .toList(growable: false);
    await file.writeAsString(jsonEncode(encoded));
  }

  Future<File> _draftsIndexFile() async {
    final Directory draftsDir = await DocumentStorageService.instance
        .getDraftsDir();
    return File('${draftsDir.path}${Platform.pathSeparator}drafts_index.json');
  }
}
