import 'dart:io';

import 'package:path_provider/path_provider.dart';

class DocumentStorageService {
  DocumentStorageService._();

  static final DocumentStorageService instance = DocumentStorageService._();

  Directory? _rootDir;
  Directory? _draftsDir;
  Directory? _exportedDir;

  Future<void> ensureDirectories() async {
    if (_rootDir != null && _draftsDir != null && _exportedDir != null) {
      return;
    }

    final Directory baseDir = await getApplicationDocumentsDirectory();
    final Directory root = Directory(
      '${baseDir.path}${Platform.pathSeparator}my_app',
    );
    final Directory drafts = Directory(
      '${root.path}${Platform.pathSeparator}drafts',
    );
    final Directory exported = Directory(
      '${root.path}${Platform.pathSeparator}exported',
    );

    await root.create(recursive: true);
    await drafts.create(recursive: true);
    await exported.create(recursive: true);

    _rootDir = root;
    _draftsDir = drafts;
    _exportedDir = exported;
  }

  Future<Directory> getDraftsDir() async {
    await ensureDirectories();
    return _draftsDir!;
  }

  Future<Directory> getExportedDir() async {
    await ensureDirectories();
    return _exportedDir!;
  }

  Future<String> copyPageToDraft(
    String sourcePath,
    String draftId,
    int index,
  ) async {
    final Directory drafts = await getDraftsDir();
    final Directory draftDir = Directory(
      '${drafts.path}${Platform.pathSeparator}$draftId',
    );
    await draftDir.create(recursive: true);

    final String extension = _extension(sourcePath);
    final String name =
        'page_${(index + 1).toString().padLeft(3, '0')}_$draftId$extension';
    final String targetPath = '${draftDir.path}${Platform.pathSeparator}$name';
    await File(sourcePath).copy(targetPath);
    return targetPath;
  }

  String _extension(String path) {
    final int dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) {
      return '.jpg';
    }
    return path.substring(dot);
  }
}
