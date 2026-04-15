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

    final Directory root = await _resolveRootDirectory();
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

  Future<Directory> _resolveRootDirectory() async {
    if (Platform.isAndroid) {
      final List<String> candidates = <String>[
        '/storage/emulated/0/my_app',
        '/sdcard/my_app',
      ];

      for (final String candidate in candidates) {
        final Directory dir = Directory(candidate);
        try {
          await dir.create(recursive: true);
          if (await _isWritable(dir)) {
            return dir;
          }
        } catch (_) {
          // Try the next candidate.
        }
      }
    }

    final Directory baseDir = await getApplicationDocumentsDirectory();
    return Directory('${baseDir.path}${Platform.pathSeparator}my_app');
  }

  Future<bool> _isWritable(Directory directory) async {
    final String probePath =
        '${directory.path}${Platform.pathSeparator}.write_probe';
    final File probe = File(probePath);
    try {
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
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
