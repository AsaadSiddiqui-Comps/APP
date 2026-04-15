import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/app_permission_service.dart';
import '../../home/screens/home_screen.dart';

class PermissionGateScreen extends StatefulWidget {
  const PermissionGateScreen({super.key});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen> {
  bool _loading = true;
  PermissionCheckResult? _lastResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestAndContinue();
    });
  }

  Future<void> _requestAndContinue() async {
    setState(() {
      _loading = true;
    });

    final PermissionCheckResult result = await AppPermissionService.instance
        .requestRequiredPermissions();

    if (!mounted) {
      return;
    }

    if (result.allGranted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
      return;
    }

    setState(() {
      _lastResult = result;
      _loading = false;
    });
  }

  Future<void> _openSettings() async {
    await openAppSettings();
    if (!mounted) {
      return;
    }
    await _requestAndContinue();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final Color panel = isDark
        ? AppColors.darkSurfaceContainer
        : AppColors.lightSurfaceContainer;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(22),
              ),
              child: _loading
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text('Checking required permissions...'),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permissions Required',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This app needs camera and storage permissions for scanning, drafts, and exports.',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Not granted:',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        ...(_lastResult?.denied ?? <Permission>[]).map(
                          (Permission permission) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.block, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  AppPermissionService.instance.permissionLabel(
                                    permission,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if ((_lastResult?.permanentlyDenied.isNotEmpty ??
                            false))
                          const Text(
                            'One or more permissions were permanently denied. Open app settings and allow them.',
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _requestAndContinue,
                                child: const Text('Retry'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: _openSettings,
                                child: const Text('Open Settings'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
