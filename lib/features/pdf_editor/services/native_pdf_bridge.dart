import 'package:flutter/services.dart';

class NativePdfBridge {
  static const MethodChannel _channel = MethodChannel('pdf_editor');

  Future<void> loadPdf(String path) async {
    await _channel.invokeMethod('loadPdf', <String, dynamic>{'path': path});
  }

  Future<void> drawStroke(List<Map<String, double>> points, int color, double width) async {
    await _channel.invokeMethod('drawStroke', <String, dynamic>{
      'points': points,
      'color': color,
      'width': width,
    });
  }

  Future<void> addHighlight(Map<String, dynamic> rect) async {
    await _channel.invokeMethod('addHighlight', rect);
  }

  Future<void> addText(String text, double x, double y, {int color = 0xFF000000, double fontSize = 16.0}) async {
    await _channel.invokeMethod('addText', <String, dynamic>{
      'text': text,
      'x': x,
      'y': y,
      'color': color,
      'fontSize': fontSize,
    });
  }

  Future<void> addImage(String path, double x, double y, {double width = 100.0, double height = 100.0}) async {
    await _channel.invokeMethod('addImage', <String, dynamic>{
      'path': path,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    });
  }

  Future<void> updateText(
    String id,
    double x,
    double y, {
    required int color,
    required double fontSize,
    required String text,
  }) async {
    await _channel.invokeMethod('updateText', <String, dynamic>{
      'id': id,
      'text': text,
      'x': x,
      'y': y,
      'color': color,
      'fontSize': fontSize,
    });
  }

  Future<void> updateImage(
    String id,
    double x,
    double y, {
    required double width,
    required double height,
    required String path,
  }) async {
    await _channel.invokeMethod('updateImage', <String, dynamic>{
      'id': id,
      'path': path,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    });
  }

  Future<void> deleteText(String id) async {
    await _channel.invokeMethod('deleteText', <String, dynamic>{'id': id});
  }

  Future<void> deleteImage(String id) async {
    await _channel.invokeMethod('deleteImage', <String, dynamic>{'id': id});
  }

  Future<void> addPage({int? afterPage}) async {
    await _channel.invokeMethod('addPage', <String, dynamic>{
      'afterPage': afterPage,
    });
  }

  Future<String> savePdf() async {
    final String? path = await _channel.invokeMethod<String>('savePdf');
    return path ?? '';
  }

  Future<void> setCurrentPage(int page) async {
    await _channel.invokeMethod('setCurrentPage', <String, dynamic>{'page': page});
  }

  Future<int> getPageCount() async {
    final int? count = await _channel.invokeMethod<int>('getPageCount');
    return count ?? 1;
  }
}
