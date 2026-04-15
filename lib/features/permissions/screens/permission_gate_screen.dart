import 'dart:io';

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
  PermissionCheckResult? _requiredResult;
  PermissionCheckResult? _optionalResult;

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

    final PermissionCheckResult required = await AppPermissionService.instance
        .requestRequiredPermissions();

    if (!mounted) {
      return;
    }

    if (!required.allGranted) {
      setState(() {
        _requiredResult = required;
        _loading = false;
      });
      return;
    }

    await _checkOptional();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _checkOptional() async {
    if (Platform.isAndroid) {
      final PermissionStatus status =
          await Permission.manageExternalStorage.status;
      setState(() {
        _optionalResult = PermissionCheckResult(
          allGranted: status.isGranted,
          denied: status.isGranted
              ? <Permission>[]
              : <Permission>[Permission.manageExternalStorage],
          permanentlyDenied: status.isPermanentlyDenied
              ? <Permission>[Permission.manageExternalStorage]
              : <Permission>[],
        );
      });
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
    if (!mounted) {
      return;
    }
    await _requestAndContinue();
  }

  Widget _buildRequiredScreen() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permissions Required',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'This app needs camera and photo permissions to scan and import documents.',
        ),
        const SizedBox(height: 16),
        Text('Not granted:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...(_requiredResult?.denied ?? <Permission>[]).map(
          (Permission permission) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.block, size: 16),
                const SizedBox(width: 8),
                Text(AppPermissionService.instance.permissionLabel(permission)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if ((_requiredResult?.permanentlyDenied.isNotEmpty ?? false))
          const Text(
            'Some permissions were permanently denied. Open app settings to grant them.',
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
    );
  }

  Widget _buildOptionalScreen() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Set!',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text('Core permissions are granted. You can now use the app.'),
        if (_optionalResult != null && _optionalResult!.denied.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainerLow
                    : AppColors.lightSurfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Optional: All Files Access',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'For broader export flexibility, you can enable all files access in Settings.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _openSettings,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                      child: const Text('Open Settings'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
              );
            },
            style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
            child: const Text('Continue'),
          ),
        ),
      ],
    );
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
                  : _requiredResult == null || _requiredResult!.allGranted
                  ? _buildOptionalScreen()
                  : _buildRequiredScreen(),
            ),
          ),
        ),
      ),
    );
  }
}
