import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

enum EditorFilterType {
  none,
  enhanced,
  pro,
  grayscale,
  blackWhite,
  vivid,
  cleanText,
  warm,
}

enum EditorResizeMode { autoFit, a4, a3 }

class ImageEditService {
  static final Map<String, String> _operationCache = <String, String>{};
  static const int _maxCacheEntries = 64;

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

  static Future<Size> readImageSize(String sourcePath) async {
    final Uint8List bytes = await File(sourcePath).readAsBytes();
    final List<double> result = await Isolate.run<List<double>>(
      () => _readImageSizeFromBytes(bytes),
    );
    return Size(result[0], result[1]);
  }

  static Future<NormalizedQuad> detectDocumentQuadNormalized(
    String sourcePath,
  ) async {
    final Uint8List bytes = await File(sourcePath).readAsBytes();
    final List<double> result = await Isolate.run<List<double>>(
      () => _detectQuadNormalizedFromBytes(bytes),
    );

    return NormalizedQuad(
      topLeft: Offset(result[0], result[1]),
      topRight: Offset(result[2], result[3]),
      bottomRight: Offset(result[4], result[5]),
      bottomLeft: Offset(result[6], result[7]),
    ).clamped();
  }

  static Future<String> cropByNormalizedQuadPerspective(
    String sourcePath,
    NormalizedQuad quad,
  ) async {
    final String op =
        'perspective_${quad.topLeft.dx}_${quad.topLeft.dy}_${quad.topRight.dx}_${quad.topRight.dy}_${quad.bottomRight.dx}_${quad.bottomRight.dy}_${quad.bottomLeft.dx}_${quad.bottomLeft.dy}';
    final String key = _cacheKey(sourcePath, op);
    final String? cached = _cachedPath(key);
    if (cached != null) {
      return cached;
    }

    final Uint8List bytes = await File(sourcePath).readAsBytes();
    final _CropRequest request = _CropRequest(
      bytes: bytes,
      quad: <double>[
        quad.topLeft.dx,
        quad.topLeft.dy,
        quad.topRight.dx,
        quad.topRight.dy,
        quad.bottomRight.dx,
        quad.bottomRight.dy,
        quad.bottomLeft.dx,
        quad.bottomLeft.dy,
      ],
    );
    final Uint8List cropped = await Isolate.run<Uint8List>(
      () => _cropPerspectiveBytes(request),
    );

    final String persisted = await _persistBytes(cropped, sourcePath, 'perspective');
    _rememberCache(key, persisted);
    return persisted;
  }

  static Future<String> rotate90(String sourcePath) async {
    return rotateByDegrees(sourcePath, 90);
  }

  static Future<String> rotateByDegrees(String sourcePath, int degrees) async {
    final String key = _cacheKey(sourcePath, 'rot_$degrees');
    final String? cached = _cachedPath(key);
    if (cached != null) {
      return cached;
    }

    final Uint8List bytes = await File(sourcePath).readAsBytes();
    final Uint8List rotated = await Isolate.run<Uint8List>(
      () => _rotateBytes(_RotateRequest(bytes: bytes, degrees: degrees)),
    );
    final String persisted = await _persistBytes(rotated, sourcePath, 'rot$degrees');
    _rememberCache(key, persisted);
    return persisted;
  }

  static Future<String> applyFilter(
    String sourcePath,
    EditorFilterType filter,
  ) async {
    if (filter == EditorFilterType.none) {
      return sourcePath;
    }

    final String key = _cacheKey(sourcePath, 'filter_${filter.name}_full');
    final String? cached = _cachedPath(key);
    if (cached != null) {
      return cached;
    }

    final Uint8List bytes = await File(sourcePath).readAsBytes();
    final Uint8List filtered = await Isolate.run<Uint8List>(
      () => _filterBytes(
        _FilterRequest(
          bytes: bytes,
          filterName: filter.name,
          previewWidth: null,
        ),
      ),
    );

    final String persisted = await _persistBytes(filtered, sourcePath, 'filter');
    _rememberCache(key, persisted);
    return persisted;
  }

  static Future<String> applyFilterPreview(
    String sourcePath,
    EditorFilterType filter,
  ) async {
    if (filter == EditorFilterType.none) {
      return sourcePath;
    }

    final String key = _cacheKey(sourcePath, 'filter_${filter.name}_preview_600');
    final String? cached = _cachedPath(key);
    if (cached != null) {
      return cached;
    }

    final Uint8List bytes = await File(sourcePath).readAsBytes();
    final Uint8List filtered = await Isolate.run<Uint8List>(
      () => _filterBytes(
        _FilterRequest(
          bytes: bytes,
          filterName: filter.name,
          previewWidth: 600,
        ),
      ),
    );

    final String persisted = await _persistBytes(
      filtered,
      sourcePath,
      'preview_${filter.name}',
      quality: 85,
    );
    _rememberCache(key, persisted);
    return persisted;
  }

  static Future<String> resize(String sourcePath, EditorResizeMode mode) async {
    final String key = _cacheKey(sourcePath, 'resize_${mode.name}');
    final String? cached = _cachedPath(key);
    if (cached != null) {
      return cached;
    }

    final Uint8List bytes = await File(sourcePath).readAsBytes();
    final Uint8List resized = await Isolate.run<Uint8List>(
      () => _resizeBytes(_ResizeRequest(bytes: bytes, modeName: mode.name)),
    );

    final String persisted = await _persistBytes(resized, sourcePath, 'resize');
    _rememberCache(key, persisted);
    return persisted;
  }

  static img.Image _applyFilterToImage(
    img.Image image,
    EditorFilterType filter,
  ) {
    switch (filter) {
      case EditorFilterType.none:
        return image;
      case EditorFilterType.enhanced:
        image = img.adjustColor(
          image,
          contrast: 1.12,
          saturation: 1.08,
          brightness: 1.03,
        );
        image = img.smooth(image, weight: 0.3);
        return image;
      case EditorFilterType.pro:
        image = img.adjustColor(
          image,
          contrast: 1.25,
          saturation: 1.0,
          brightness: 1.07,
        );
        image = img.convolution(
          image,
          filter: <num>[0, -1, 0, -1, 5, -1, 0, -1, 0],
        );
        return image;
      case EditorFilterType.grayscale:
        return img.grayscale(image);
      case EditorFilterType.blackWhite:
        image = img.grayscale(image);
        image = img.adjustColor(image, contrast: 1.55);
        image = img.luminanceThreshold(image, threshold: 0.57);
        return image;
      case EditorFilterType.vivid:
        image = img.adjustColor(
          image,
          contrast: 1.2,
          saturation: 1.25,
          brightness: 1.05,
        );
        return image;
      case EditorFilterType.cleanText:
        image = img.grayscale(image);
        image = img.adjustColor(image, contrast: 1.7, brightness: 1.08);
        image = img.convolution(
          image,
          filter: <num>[0, -1, 0, -1, 5, -1, 0, -1, 0],
        );
        image = img.luminanceThreshold(image, threshold: 0.56);
        return image;
      case EditorFilterType.warm:
        image = img.adjustColor(
          image,
          contrast: 1.08,
          saturation: 1.1,
          brightness: 1.04,
        );
        image = img.colorOffset(image, red: 10, green: 2, blue: -8);
        return image;
    }
  }

  static Future<String> _persistBytes(
    Uint8List bytes,
    String sourcePath,
    String tag, {
    int quality = 95,
  }) async {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not decode processed image');
    }
    final Directory parent = File(sourcePath).parent;
    final String fileName =
        'edited_${DateTime.now().millisecondsSinceEpoch}_$tag.jpg';
    final File output = File(
      '${parent.path}${Platform.pathSeparator}$fileName',
    );
    await output.writeAsBytes(img.encodeJpg(decoded, quality: quality));
    return output.path;
  }

  static _Bounds _estimateDocumentBounds(img.Image image) {
    final int marginX = (image.width * 0.04).round();
    final int marginY = (image.height * 0.04).round();

    int left = marginX;
    int top = marginY;
    int right = image.width - marginX;
    int bottom = image.height - marginY;

    final int baseline = _cornerBrightnessAverage(image);
    final int threshold = (baseline - 18).clamp(18, 230);

    while (left < right - 60 &&
        _isMostlyBackgroundColumn(image, left, threshold)) {
      left += 2;
    }
    while (right > left + 60 &&
        _isMostlyBackgroundColumn(image, right - 1, threshold)) {
      right -= 2;
    }
    while (top < bottom - 60 && _isMostlyBackgroundRow(image, top, threshold)) {
      top += 2;
    }
    while (bottom > top + 60 &&
        _isMostlyBackgroundRow(image, bottom - 1, threshold)) {
      bottom -= 2;
    }

    if (right - left < image.width * 0.45 ||
        bottom - top < image.height * 0.45) {
      return _Bounds(
        x: marginX,
        y: marginY,
        width: image.width - marginX * 2,
        height: image.height - marginY * 2,
      );
    }

    return _Bounds(x: left, y: top, width: right - left, height: bottom - top);
  }

  static int _cornerBrightnessAverage(img.Image image) {
    final List<int> values = <int>[
      _pixelLuma(image, 2, 2),
      _pixelLuma(image, image.width - 3, 2),
      _pixelLuma(image, 2, image.height - 3),
      _pixelLuma(image, image.width - 3, image.height - 3),
    ];

    return (values.reduce((int a, int b) => a + b) / values.length).round();
  }

  static bool _isMostlyBackgroundColumn(img.Image image, int x, int threshold) {
    int brightPixels = 0;
    int sampled = 0;
    for (int y = 0; y < image.height; y += 8) {
      sampled += 1;
      if (_pixelLuma(image, x, y) >= threshold) {
        brightPixels += 1;
      }
    }
    return brightPixels >= (sampled * 0.9).round();
  }

  static bool _isMostlyBackgroundRow(img.Image image, int y, int threshold) {
    int brightPixels = 0;
    int sampled = 0;
    for (int x = 0; x < image.width; x += 8) {
      sampled += 1;
      if (_pixelLuma(image, x, y) >= threshold) {
        brightPixels += 1;
      }
    }
    return brightPixels >= (sampled * 0.9).round();
  }

  static int _pixelLuma(img.Image image, int x, int y) {
    final img.Pixel pixel = image.getPixel(
      x.clamp(0, image.width - 1),
      y.clamp(0, image.height - 1),
    );
    return ((pixel.r + pixel.g + pixel.b) / 3).round();
  }

  static List<double> _computeHomography({
    required List<Offset> from,
    required List<Offset> to,
  }) {
    final List<List<double>> a = List<List<double>>.generate(
      8,
      (_) => List<double>.filled(8, 0),
    );
    final List<double> b = List<double>.filled(8, 0);

    for (int i = 0; i < 4; i += 1) {
      final double x = from[i].dx;
      final double y = from[i].dy;
      final double u = to[i].dx;
      final double v = to[i].dy;

      final int r = i * 2;
      a[r][0] = x;
      a[r][1] = y;
      a[r][2] = 1;
      a[r][3] = 0;
      a[r][4] = 0;
      a[r][5] = 0;
      a[r][6] = -u * x;
      a[r][7] = -u * y;
      b[r] = u;

      a[r + 1][0] = 0;
      a[r + 1][1] = 0;
      a[r + 1][2] = 0;
      a[r + 1][3] = x;
      a[r + 1][4] = y;
      a[r + 1][5] = 1;
      a[r + 1][6] = -v * x;
      a[r + 1][7] = -v * y;
      b[r + 1] = v;
    }

    final List<double> h = _solveLinearSystem(a, b);
    return <double>[h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], 1.0];
  }

  static List<double> _solveLinearSystem(List<List<double>> a, List<double> b) {
    final int n = b.length;

    for (int i = 0; i < n; i += 1) {
      int pivot = i;
      double max = a[i][i].abs();
      for (int r = i + 1; r < n; r += 1) {
        final double v = a[r][i].abs();
        if (v > max) {
          max = v;
          pivot = r;
        }
      }

      if (pivot != i) {
        final List<double> row = a[i];
        a[i] = a[pivot];
        a[pivot] = row;
        final double bv = b[i];
        b[i] = b[pivot];
        b[pivot] = bv;
      }

      final double div = a[i][i];
      if (div.abs() < 1e-9) {
        throw Exception('Homography solve failed due to singular matrix');
      }

      for (int c = i; c < n; c += 1) {
        a[i][c] /= div;
      }
      b[i] /= div;

      for (int r = 0; r < n; r += 1) {
        if (r == i) {
          continue;
        }
        final double f = a[r][i];
        if (f == 0) {
          continue;
        }
        for (int c = i; c < n; c += 1) {
          a[r][c] -= f * a[i][c];
        }
        b[r] -= f * b[i];
      }
    }

    return b;
  }

  static Offset _applyHomography(List<double> h, double x, double y) {
    final double denom = h[6] * x + h[7] * y + h[8];
    final double sx = (h[0] * x + h[1] * y + h[2]) / denom;
    final double sy = (h[3] * x + h[4] * y + h[5]) / denom;
    return Offset(sx, sy);
  }
}

class NormalizedQuad {
  const NormalizedQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  NormalizedQuad copyWith({
    Offset? topLeft,
    Offset? topRight,
    Offset? bottomRight,
    Offset? bottomLeft,
  }) {
    return NormalizedQuad(
      topLeft: topLeft ?? this.topLeft,
      topRight: topRight ?? this.topRight,
      bottomRight: bottomRight ?? this.bottomRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
    );
  }

  NormalizedQuad clamped() {
    return NormalizedQuad(
      topLeft: _clampOffset(topLeft),
      topRight: _clampOffset(topRight),
      bottomRight: _clampOffset(bottomRight),
      bottomLeft: _clampOffset(bottomLeft),
    );
  }

  Offset _clampOffset(Offset value) {
    return Offset(value.dx.clamp(0.0, 1.0), value.dy.clamp(0.0, 1.0));
  }
}

class _Bounds {
  const _Bounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;
}

class _CropRequest {
  const _CropRequest({required this.bytes, required this.quad});

  final Uint8List bytes;
  final List<double> quad;
}

class _RotateRequest {
  const _RotateRequest({required this.bytes, required this.degrees});

  final Uint8List bytes;
  final int degrees;
}

class _FilterRequest {
  const _FilterRequest({
    required this.bytes,
    required this.filterName,
    required this.previewWidth,
  });

  final Uint8List bytes;
  final String filterName;
  final int? previewWidth;
}

class _ResizeRequest {
  const _ResizeRequest({required this.bytes, required this.modeName});

  final Uint8List bytes;
  final String modeName;
}

List<double> _readImageSizeFromBytes(Uint8List bytes) {
  final img.Image? image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Could not decode image');
  }
  return <double>[image.width.toDouble(), image.height.toDouble()];
}

List<double> _detectQuadNormalizedFromBytes(Uint8List bytes) {
  final img.Image? image = img.decodeImage(bytes);
  if (image == null) {
    throw Exception('Could not decode image');
  }

  final _Bounds bounds = ImageEditService._estimateDocumentBounds(image);
  return <double>[
    bounds.x / image.width,
    bounds.y / image.height,
    (bounds.x + bounds.width) / image.width,
    bounds.y / image.height,
    (bounds.x + bounds.width) / image.width,
    (bounds.y + bounds.height) / image.height,
    bounds.x / image.width,
    (bounds.y + bounds.height) / image.height,
  ];
}

Uint8List _cropPerspectiveBytes(_CropRequest request) {
  final img.Image? source = img.decodeImage(request.bytes);
  if (source == null) {
    throw Exception('Could not decode image');
  }

  final NormalizedQuad safe = NormalizedQuad(
    topLeft: Offset(request.quad[0], request.quad[1]),
    topRight: Offset(request.quad[2], request.quad[3]),
    bottomRight: Offset(request.quad[4], request.quad[5]),
    bottomLeft: Offset(request.quad[6], request.quad[7]),
  ).clamped();

  final List<Offset> src = <Offset>[
    Offset(safe.topLeft.dx * source.width, safe.topLeft.dy * source.height),
    Offset(safe.topRight.dx * source.width, safe.topRight.dy * source.height),
    Offset(safe.bottomRight.dx * source.width, safe.bottomRight.dy * source.height),
    Offset(safe.bottomLeft.dx * source.width, safe.bottomLeft.dy * source.height),
  ];

  final double widthTop = (src[1] - src[0]).distance;
  final double widthBottom = (src[2] - src[3]).distance;
  final double heightRight = (src[2] - src[1]).distance;
  final double heightLeft = (src[3] - src[0]).distance;

  final int outWidth = math.max(widthTop, widthBottom).round().clamp(64, 5000);
  final int outHeight = math.max(heightLeft, heightRight).round().clamp(64, 5000);

  final List<Offset> dst = <Offset>[
    const Offset(0, 0),
    Offset(outWidth - 1.0, 0),
    Offset(outWidth - 1.0, outHeight - 1.0),
    Offset(0, outHeight - 1.0),
  ];

  final List<double> h = ImageEditService._computeHomography(from: dst, to: src);
  final img.Image out = img.Image(width: outWidth, height: outHeight);

  for (int y = 0; y < outHeight; y += 1) {
    for (int x = 0; x < outWidth; x += 1) {
      final Offset s = ImageEditService._applyHomography(h, x.toDouble(), y.toDouble());
      final int sx = s.dx.round();
      final int sy = s.dy.round();

      if (sx < 0 || sy < 0 || sx >= source.width || sy >= source.height) {
        out.setPixelRgba(x, y, 255, 255, 255, 255);
      } else {
        final img.Pixel p = source.getPixel(sx, sy);
        out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), p.a.toInt());
      }
    }
  }

  return Uint8List.fromList(img.encodeJpg(out, quality: 95));
}

Uint8List _rotateBytes(_RotateRequest request) {
  final img.Image? image = img.decodeImage(request.bytes);
  if (image == null) {
    throw Exception('Could not decode image');
  }
  final img.Image rotated = img.copyRotate(image, angle: request.degrees);
  return Uint8List.fromList(img.encodeJpg(rotated, quality: 95));
}

Uint8List _filterBytes(_FilterRequest request) {
  final img.Image? decoded = img.decodeImage(request.bytes);
  if (decoded == null) {
    throw Exception('Could not decode image');
  }

  img.Image image = decoded;
  if (request.previewWidth != null && image.width > request.previewWidth!) {
    image = img.copyResize(
      image,
      width: request.previewWidth,
      interpolation: img.Interpolation.linear,
    );
  }

  final EditorFilterType filter = EditorFilterType.values.firstWhere(
    (EditorFilterType f) => f.name == request.filterName,
    orElse: () => EditorFilterType.none,
  );

  image = ImageEditService._applyFilterToImage(image, filter);
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

Uint8List _resizeBytes(_ResizeRequest request) {
  final img.Image? image = img.decodeImage(request.bytes);
  if (image == null) {
    throw Exception('Could not decode image');
  }

  final EditorResizeMode mode = EditorResizeMode.values.firstWhere(
    (EditorResizeMode v) => v.name == request.modeName,
    orElse: () => EditorResizeMode.autoFit,
  );

  int targetWidth;
  int targetHeight;
  switch (mode) {
    case EditorResizeMode.autoFit:
      targetWidth = 1240;
      targetHeight = 1754;
      break;
    case EditorResizeMode.a4:
      targetWidth = 1654;
      targetHeight = 2339;
      break;
    case EditorResizeMode.a3:
      targetWidth = 2339;
      targetHeight = 3307;
      break;
  }

  final bool isLandscape = image.width > image.height;
  if (isLandscape) {
    final int oldWidth = targetWidth;
    targetWidth = targetHeight;
    targetHeight = oldWidth;
  }

  final img.Image resized = img.copyResize(
    image,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.average,
  );

  return Uint8List.fromList(img.encodeJpg(resized, quality: 95));
}
