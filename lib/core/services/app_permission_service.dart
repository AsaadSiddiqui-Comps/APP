import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermissionCheckResult {
  PermissionCheckResult({
    required this.allGranted,
    required this.denied,
    required this.permanentlyDenied,
  });

  final bool allGranted;
  final List<Permission> denied;
  final List<Permission> permanentlyDenied;
}

class AppPermissionService {
  AppPermissionService._();

  static final AppPermissionService instance = AppPermissionService._();

  List<Permission> requiredPermissions() {
    if (Platform.isAndroid || Platform.isIOS) {
      return <Permission>[Permission.camera, Permission.photos];
    }
    return <Permission>[Permission.camera];
  }

  List<Permission> optionalStoragePermissions() {
    if (Platform.isAndroid) {
      return <Permission>[Permission.manageExternalStorage];
    }
    return <Permission>[];
  }

  Future<bool> hasAllPermissions() async {
    final List<Permission> permissions = requiredPermissions();
    for (final Permission permission in permissions) {
      final PermissionStatus status = await permission.status;
      if (!status.isGranted) {
        return false;
      }
    }
    return true;
  }

  Future<PermissionCheckResult> requestRequiredPermissions() async {
    final List<Permission> permissions = requiredPermissions();
    final Map<Permission, PermissionStatus> statuses = await permissions
        .request();

    final List<Permission> denied = <Permission>[];
    final List<Permission> permanentlyDenied = <Permission>[];

    statuses.forEach((Permission permission, PermissionStatus status) {
      if (!status.isGranted) {
        denied.add(permission);
      }
      if (status.isPermanentlyDenied || status.isRestricted) {
        permanentlyDenied.add(permission);
      }
    });

    return PermissionCheckResult(
      allGranted: denied.isEmpty,
      denied: denied,
      permanentlyDenied: permanentlyDenied,
    );
  }

  String permissionLabel(Permission permission) {
    if (permission == Permission.camera) {
      return 'Camera';
    }
    if (permission == Permission.photos) {
      return 'Photos & Videos';
    }
    if (permission == Permission.manageExternalStorage) {
      return 'All Files Access (optional)';
    }
    return permission.toString();
  }
}
