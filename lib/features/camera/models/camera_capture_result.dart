import 'package:camera/camera.dart';

class CameraCaptureResult {
  const CameraCaptureResult({required this.images});

  final List<XFile> images;
}
