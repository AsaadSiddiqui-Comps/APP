import 'package:flutter/material.dart';

import 'config/theme.dart';
import 'core/services/external_file_open_service.dart';
import 'features/files/screens/pdf_viewer_screen.dart';
import 'features/home/screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Docly',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const _LaunchRouterScreen(),
    );
  }
}

class _LaunchRouterScreen extends StatefulWidget {
  const _LaunchRouterScreen();

  @override
  State<_LaunchRouterScreen> createState() => _LaunchRouterScreenState();
}

class _LaunchRouterScreenState extends State<_LaunchRouterScreen> {
  late final Future<String?> _pendingPathFuture;

  @override
  void initState() {
    super.initState();
    _pendingPathFuture = ExternalFileOpenService.consumePendingPdfPath();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _pendingPathFuture,
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          );
        }

        final String? path = snapshot.data;
        if (path != null && path.isNotEmpty) {
          return PdfViewerScreen(pdfPath: path, title: 'External PDF');
        }
        return const HomeScreen();
      },
    );
  }
}
