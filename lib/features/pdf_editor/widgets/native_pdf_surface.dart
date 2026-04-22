import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NativePdfSurface extends StatelessWidget {
  const NativePdfSurface({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const AndroidView(viewType: 'pdf_render_view', layoutDirection: TextDirection.ltr);
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const UiKitView(viewType: 'pdf_render_view', layoutDirection: TextDirection.ltr);
    }

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: const Text(
        'Native PDF surface is only available on Android and iOS.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
