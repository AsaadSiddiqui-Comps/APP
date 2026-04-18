import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service for native rendering of drawing/erasing operations
/// Provides high-performance drawing via platform channels
class NativeDrawingService {
  static const platform = MethodChannel('com.docly.pdf_drawing/native_renderer');

  /// Initialize native drawing context for a specific canvas size
  static Future<bool> initializeDrawingContext({
    required int width,
    required int height,
  }) async {
    try {
      final bool result = await platform.invokeMethod<bool>(
        'initDrawingContext',
        {
          'width': width,
          'height': height,
        },
      ) ?? false;
      return result;
    } catch (e) {
      debugPrint('Error initializing native drawing context: $e');
      return false;
    }
  }

  /// Add a stroke to the native drawing buffer
  /// Points are flattened as [x1, y1, x2, y2, ...]
  static Future<void> drawStroke({
    required List<double> flatPoints,
    required int colorARGB,
    required double strokeWidth,
    required double opacity,
  }) async {
    try {
      await platform.invokeMethod('drawStroke', {
        'points': flatPoints,
        'color': colorARGB,
        'strokeWidth': strokeWidth,
        'opacity': opacity,
      });
    } catch (e) {
      debugPrint('Error drawing stroke: $e');
    }
  }

  /// Erase portions of strokes within a circular area
  static Future<void> erase({
    required double centerX,
    required double centerY,
    required double radius,
  }) async {
    try {
      await platform.invokeMethod('erase', {
        'centerX': centerX,
        'centerY': centerY,
        'radius': radius,
      });
    } catch (e) {
      debugPrint('Error erasing: $e');
    }
  }

  /// Render the current drawing buffer to PNG bytes
  static Future<Uint8List?> renderToPNG() async {
    try {
      final Uint8List? result = await platform.invokeMethod<Uint8List>(
        'renderToPNG',
      );
      return result;
    } catch (e) {
      debugPrint('Error rendering to PNG: $e');
      return null;
    }
  }

  /// Clear all drawing operations and reset buffer
  static Future<void> clearBuffer() async {
    try {
      await platform.invokeMethod('clearBuffer');
    } catch (e) {
      debugPrint('Error clearing buffer: $e');
    }
  }

  /// Undo the last drawing operation
  static Future<bool> undo() async {
    try {
      final bool result = await platform.invokeMethod<bool>(
        'undo',
      ) ?? false;
      return result;
    } catch (e) {
      debugPrint('Error undoing: $e');
      return false;
    }
  }

  /// Redo the last undone operation
  static Future<bool> redo() async {
    try {
      final bool result = await platform.invokeMethod<bool>(
        'redo',
      ) ?? false;
      return result;
    } catch (e) {
      debugPrint('Error redoing: $e');
      return false;
    }
  }

  /// Get total number of strokes in the buffer
  static Future<int> getStrokeCount() async {
    try {
      final int? count = await platform.invokeMethod<int>(
        'getStrokeCount',
      );
      return count ?? 0;
    } catch (e) {
      debugPrint('Error getting stroke count: $e');
      return 0;
    }
  }
}
