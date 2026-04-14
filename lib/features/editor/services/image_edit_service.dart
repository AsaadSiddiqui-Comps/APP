import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

enum EditorFilterType {
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
  static Future<NormalizedCropRect> detectDocumentRectNormalized(
    String sourcePath,
  ) async {
    final img.Image image = await _decode(sourcePath);
    final _Bounds bounds = _estimateDocumentBounds(image);
    return NormalizedCropRect(
      left: bounds.x / image.width,
      top: bounds.y / image.height,
      right: (bounds.x + bounds.width) / image.width,
      bottom: (bounds.y + bounds.height) / image.height,
    ).clamped();
  }

  static Future<String> cropByNormalizedRect(
    String sourcePath,
    NormalizedCropRect rect,
  ) async {
    final img.Image image = await _decode(sourcePath);
    final NormalizedCropRect safe = rect.clamped();

    final int x = (safe.left * image.width).round().clamp(0, image.width - 2);
    final int y = (safe.top * image.height).round().clamp(0, image.height - 2);
    final int right = (safe.right * image.width).round().clamp(
      x + 1,
      image.width,
    );
    final int bottom = (safe.bottom * image.height).round().clamp(
      y + 1,
      image.height,
    );

    final int width = (right - x).clamp(1, image.width);
    final int height = (bottom - y).clamp(1, image.height);

    final img.Image cropped = img.copyCrop(
      image,
      x: x,
      y: y,
      width: width,
      height: height,
    );
    return _persist(cropped, sourcePath, 'manualcrop');
  }

  static Future<String> rotate90(String sourcePath) async {
    final img.Image image = await _decode(sourcePath);
    final img.Image rotated = img.copyRotate(image, angle: 90);
    return _persist(rotated, sourcePath, 'rot');
  }

  static Future<String> autoCrop(String sourcePath) async {
    final img.Image image = await _decode(sourcePath);

    final _Bounds bounds = _estimateDocumentBounds(image);
    final img.Image cropped = img.copyCrop(
      image,
      x: bounds.x,
      y: bounds.y,
      width: bounds.width,
      height: bounds.height,
    );

    return _persist(cropped, sourcePath, 'autocrop');
  }

  static Future<String> cropCenterByRatio(
    String sourcePath,
    double ratio,
  ) async {
    final img.Image image = await _decode(sourcePath);

    int targetWidth = image.width;
    int targetHeight = (targetWidth / ratio).round();

    if (targetHeight > image.height) {
      targetHeight = image.height;
      targetWidth = (targetHeight * ratio).round();
    }

    final int x = ((image.width - targetWidth) / 2).round();
    final int y = ((image.height - targetHeight) / 2).round();

    final img.Image cropped = img.copyCrop(
      image,
      x: x,
      y: y,
      width: targetWidth,
      height: targetHeight,
    );
    return _persist(cropped, sourcePath, 'crop');
  }

  static Future<String> applyFilter(
    String sourcePath,
    EditorFilterType filter,
  ) async {
    img.Image image = await _decode(sourcePath);

    switch (filter) {
      case EditorFilterType.enhanced:
        image = img.adjustColor(
          image,
          contrast: 1.12,
          saturation: 1.08,
          brightness: 1.03,
        );
        image = img.smooth(image, weight: 0.3);
        break;
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
        break;
      case EditorFilterType.grayscale:
        image = img.grayscale(image);
        break;
      case EditorFilterType.blackWhite:
        image = img.grayscale(image);
        image = img.adjustColor(image, contrast: 1.55);
        image = img.luminanceThreshold(image, threshold: 0.57);
        break;
      case EditorFilterType.vivid:
        image = img.adjustColor(
          image,
          contrast: 1.2,
          saturation: 1.25,
          brightness: 1.05,
        );
        break;
      case EditorFilterType.cleanText:
        image = img.grayscale(image);
        image = img.adjustColor(image, contrast: 1.7, brightness: 1.08);
        image = img.convolution(
          image,
          filter: <num>[0, -1, 0, -1, 5, -1, 0, -1, 0],
        );
        image = img.luminanceThreshold(image, threshold: 0.56);
        break;
      case EditorFilterType.warm:
        image = img.adjustColor(
          image,
          contrast: 1.08,
          saturation: 1.1,
          brightness: 1.04,
        );
        image = img.colorOffset(image, red: 10, green: 2, blue: -8);
        break;
    }

    return _persist(image, sourcePath, 'filter');
  }

  static Future<String> resize(String sourcePath, EditorResizeMode mode) async {
    final img.Image image = await _decode(sourcePath);

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

    return _persist(resized, sourcePath, 'resize');
  }

  static Future<img.Image> _decode(String path) async {
    final Uint8List bytes = await File(path).readAsBytes();
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Could not decode image');
    }
    return image;
  }

  static Future<String> _persist(
    img.Image image,
    String sourcePath,
    String tag,
  ) async {
    final Directory parent = File(sourcePath).parent;
    final String fileName =
        'edited_${DateTime.now().millisecondsSinceEpoch}_$tag.jpg';
    final File output = File(
      '${parent.path}${Platform.pathSeparator}$fileName',
    );
    await output.writeAsBytes(img.encodeJpg(image, quality: 95));
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
}

class NormalizedCropRect {
  const NormalizedCropRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  NormalizedCropRect clamped() {
    final double clampedLeft = left.clamp(0.0, 1.0);
    final double clampedTop = top.clamp(0.0, 1.0);
    final double clampedRight = right.clamp(0.0, 1.0);
    final double clampedBottom = bottom.clamp(0.0, 1.0);
    const double minGap = 0.08;

    double safeLeft = clampedLeft;
    double safeTop = clampedTop;
    double safeRight = clampedRight;
    double safeBottom = clampedBottom;

    if (safeRight - safeLeft < minGap) {
      final double center = (safeLeft + safeRight) / 2;
      safeLeft = (center - minGap / 2).clamp(0.0, 1.0 - minGap);
      safeRight = safeLeft + minGap;
    }

    if (safeBottom - safeTop < minGap) {
      final double center = (safeTop + safeBottom) / 2;
      safeTop = (center - minGap / 2).clamp(0.0, 1.0 - minGap);
      safeBottom = safeTop + minGap;
    }

    return NormalizedCropRect(
      left: safeLeft,
      top: safeTop,
      right: safeRight,
      bottom: safeBottom,
    );
  }

  Rect toRect(Size size) {
    return Rect.fromLTRB(
      left * size.width,
      top * size.height,
      right * size.width,
      bottom * size.height,
    );
  }

  static NormalizedCropRect fromRect(Rect rect, Size size) {
    return NormalizedCropRect(
      left: rect.left / size.width,
      top: rect.top / size.height,
      right: rect.right / size.width,
      bottom: rect.bottom / size.height,
    ).clamped();
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
