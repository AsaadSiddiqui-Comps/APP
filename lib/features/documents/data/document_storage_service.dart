import 'dart:io';

import 'package:media_scanner/media_scanner.dart';
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
      try {
        // ✅ BEST: App-specific external storage (no permission needed, Android 11+ safe)
        final Directory? externalDir = await getExternalStorageDirectory();

        if (externalDir != null) {
          final Directory appDir = Directory(
            '${externalDir.path}${Platform.pathSeparator}my_app',
          );

          await appDir.create(recursive: true);

          if (await _isWritable(appDir)) {
            return appDir;
          }
        }
      } catch (_) {
        // Try fallback
      }
    }

    // ✅ Fallback: App Documents (always works)
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

  /// Get best export directory
  /// [customPath] = user-selected folder from file picker (SAF)
  /// If customPath is provided and writable, use it; otherwise fallback to app storage
  Future<Directory> getBestExportDirectory({String? customPath}) async {
    await ensureDirectories();

    // ✅ If user selected folder via file picker (BEST option)
    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);

      try {
        await dir.create(recursive: true);
        if (await _isWritable(dir)) {
          return dir;
        }
      } catch (_) {
        // Try fallback
      }
    }

    // ✅ Fallback to safe app storage
    return _exportedDir!;
  }

  /// Resolve Downloads export location with SAF-first strategy.
  /// 1) Use user-picked Downloads folder (SAF) when available and writable.
  /// 2) Try direct Downloads path on Android when writable.
  /// 3) Fallback to app export directory.
  Future<Directory> getBestDownloadsDirectory({String? safPath}) async {
    await ensureDirectories();

    if (safPath != null && safPath.isNotEmpty) {
      final Directory safDir = Directory(safPath);
      try {
        await safDir.create(recursive: true);
        if (await _isWritable(safDir)) {
          return safDir;
        }
      } catch (_) {
        // Try fallback
      }
    }

    if (Platform.isAndroid) {
      try {
        final Directory downloadsDir = Directory(
          '/storage/emulated/0/Download${Platform.pathSeparator}my_app',
        );
        await downloadsDir.create(recursive: true);
        if (await _isWritable(downloadsDir)) {
          return downloadsDir;
        }
      } catch (_) {
        // Try fallback
      }
    }

    return _exportedDir!;
  }

  /// Trigger media scanner to make file visible in file managers, gallery, etc.
  /// Call this after saving a file
  Future<void> scanFile(String filePath) async {
    try {
      await MediaScanner.loadMedia(path: filePath);
    } catch (_) {
      // Media scanner not available, file will still be saved
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
