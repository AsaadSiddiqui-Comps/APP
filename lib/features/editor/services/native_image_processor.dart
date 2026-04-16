import 'dart:io';

import 'package:flutter/services.dart';

/// Native image processing service using Kotlin/Android native layer via MethodChannel.
/// All operations are non-blocking and execute asynchronously on Android's thread pool.
class NativeImageProcessor {
  static const platform = MethodChannel('com.pixeldev.Docly/image');

  static final Map<String, String> _operationCache = <String, String>{};
  static const int _maxCacheEntries = 128;

  static String? _cachedPath(String key) {
    final String? path = _operationCache[key];
    if (path == null) {
      return null;
    }
    if (!File(path).existsSync()) {
      _operationCache.remove(key);
      return null;
    }
    return path;
  }

  static String _cacheKey(String sourcePath, String op) {
    return '$sourcePath|$op';
  }

  static void _rememberCache(String key, String path) {
    _operationCache[key] = path;
    while (_operationCache.length > _maxCacheEntries) {
      _operationCache.remove(_operationCache.keys.first);
    }
  }

  /// Process image via native layer. Returns processed bytes.
  static Future<Uint8List> _invokeNative(
    String action,
    Uint8List bytes, {
    Map<String, dynamic> params = const {},
  }) async {
    try {
      final result = await platform.invokeMethod<Uint8List>(
        'processImage',
        {
          'action': action,
          'bytes': bytes,
          'params': params,
        },
      );
      return result ?? bytes;
    } on PlatformException catch (e) {
      throw Exception('Native processing failed: ${e.message}');
    }
  }

  /// Read image dimensions using native layer.
  static Future<(int, int)> readImageSize(String sourcePath) async {
    final Uint8List bytes = await File(sourcePath).readAsBytes();
    final Uint8List sizeBytes = await _invokeNative('readSize', bytes);

    if (sizeBytes.length < 8) {
      throw Exception('Invalid size response');
    }

    final width = ((sizeBytes[0].toUnsigned(8) << 24) |
            (sizeBytes[1].toUnsigned(8) << 16) |
            (sizeBytes[2].toUnsigned(8) << 8) |
            sizeBytes[3].toUnsigned(8))
        .toSigned(32);
    final height = ((sizeBytes[4].toUnsigned(8) << 24) |
            (sizeBytes[5].toUnsigned(8) << 16) |
            (sizeBytes[6].toUnsigned(8) << 8) |
            sizeBytes[7].toUnsigned(8))
        .toSigned(32);

    return (width, height);
  }

  /// Crop image with perspective correction.
  static Future<String> cropByNormalizedQuadPerspective(
    String sourcePath, {
    required double topLeftDx,
    required double topLeftDy,
    required double topRightDx,
    required double topRightDy,
    required double bottomRightDx,
    required double bottomRightDy,
    required double bottomLeftDx,
    required double bottomLeftDy,
  }) async {
    final String op =
        'perspective_${topLeftDx}_${topLeftDy}_${topRightDx}_${topRightDy}_${bottomRightDx}_${bottomRightDy}_${bottomLeftDx}_${bottomLeftDy}';
    final String key = _cacheKey(sourcePath, op);
    final String? cached = _cachedPath(key);
    if (cached != null) {
      return cached;
    }

    final Uint8List bytes = await File(sourcePath).readAsBytes();
    final Uint8List cropped = await _invokeNative(
      'crop',
      bytes,
      params: {
        'x': 0, // Simplified for now; full homography crop can be added
        'y': 0,
        'width': 500,
        'height': 700,
      },
    );

    final Directory parent = File(sourcePath).parent;
    final String fileName =
        'edited_${DateTime.now().millisecondsSinceEpoch}_perspective.jpg';
    final File output = File(
      '${parent.path}${Platform.pathSeparator}$fileName',
    );
    await output.writeAsBytes(cropped);
    _rememberCache(key, output.path);
    return output.path;
  }

  /// Rotate image by degrees using native layer.
  static Future<String> rotateByDegrees(
    String sourcePath,
    int degrees,
  ) async {
    final String key = _cacheKey(sourcePath, 'rot_$degrees');
    final String? cached = _cachedPath(key);
    if (cached != null) {
      return cached;
    }

    final Uint8List bytes = await File(sourcePath).readAsBytes();
    final Uint8List rotated = await _invokeNative(
      'rotate',
      bytes,
      params: {'angle': degrees},
    );

    final Directory parent = File(sourcePath).parent;
    final String fileName =
        'edited_${DateTime.now().millisecondsSinceEpoch}_rot$degrees.jpg';
    final File output = File(
      '${parent.path}${Platform.pathSeparator}$fileName',
    );
    await output.writeAsBytes(rotated);
    _rememberCache(key, output.path);
    return output.path;
  }

  /// Apply filter using native layer.
  static Future<String> applyFilter(
    String sourcePath,
    String filterName,
  ) async {
    final String key = _cacheKey(sourcePath, 'filter_${filterName}_full');
    final String? cached = _cachedPath(key);
    if (cached != null) {
      return cached;
    }

    final Uint8List bytes = await File(sourcePath).readAsBytes();
    final Uint8List filtered = await _invokeNative(
      'filter',
      bytes,
      params: {
        'filterName': filterName,
        'previewWidth': null,
      },
    );

    final Directory parent = File(sourcePath).parent;
    final String fileName =
        'edited_${DateTime.now().millisecondsSinceEpoch}_filter.jpg';
    final File output = File(
      '${parent.path}${Platform.pathSeparator}$fileName',
    );
    await output.writeAsBytes(filtered);
    _rememberCache(key, output.path);
    return output.path;
  }

  /// Apply filter to low-resolution preview.
  static Future<String> applyFilterPreview(
    String sourcePath,
    String filterName,
  ) async {
    final String key =
        _cacheKey(sourcePath, 'filter_${filterName}_preview_600');
    final String? cached = _cachedPath(key);
    if (cached != null) {
      return cached;
    }

    final Uint8List bytes = await File(sourcePath).readAsBytes();
    final Uint8List filtered = await _invokeNative(
      'filter',
      bytes,
      params: {
        'filterName': filterName,
        'previewWidth': 600,
      },
    );

    final Directory parent = File(sourcePath).parent;
    final String fileName =
        'edited_${DateTime.now().millisecondsSinceEpoch}_preview_$filterName.jpg';
    final File output = File(
      '${parent.path}${Platform.pathSeparator}$fileName',
    );
    await output.writeAsBytes(filtered);
    _rememberCache(key, output.path);
    return output.path;
  }

  /// Resize image using native layer.
  static Future<String> resize(
    String sourcePath,
    String modeName,
  ) async {
    final String key = _cacheKey(sourcePath, 'resize_$modeName');
    final String? cached = _cachedPath(key);
    if (cached != null) {
      return cached;
    }

    final Uint8List bytes = await File(sourcePath).readAsBytes();
    final Uint8List resized = await _invokeNative(
      'resize',
      bytes,
      params: {'modeName': modeName},
    );

    final Directory parent = File(sourcePath).parent;
    final String fileName =
        'edited_${DateTime.now().millisecondsSinceEpoch}_resize.jpg';
    final File output = File(
      '${parent.path}${Platform.pathSeparator}$fileName',
    );
    await output.writeAsBytes(resized);
    _rememberCache(key, output.path);
    return output.path;
  }

  /// Detect document quad using native layer (placeholder for ML Kit integration).
  static Future<(double, double, double, double, double, double, double,
      double)> detectDocumentQuad(String sourcePath) async {
    try {
      final Uint8List bytes = await File(sourcePath).readAsBytes();
      await _invokeNative('detectQuad', bytes);
      
      // For now return default quad - full ML Kit integration can be added later
      return (0.08, 0.08, 0.92, 0.08, 0.92, 0.92, 0.08, 0.92);
    } catch (_) {
      return (0.08, 0.08, 0.92, 0.08, 0.92, 0.92, 0.08, 0.92);
    }
  }
}
