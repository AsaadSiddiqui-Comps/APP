import 'package:flutter/services.dart';

class ExternalFileOpenService {
  ExternalFileOpenService._();

  static const MethodChannel _channel = MethodChannel('com.pixeldev.Docly/file_open');

  static Future<String?> consumePendingPdfPath() async {
    try {
      return await _channel.invokeMethod<String>('consumePendingPdfPath');
    } catch (_) {
      return null;
    }
  }
}
