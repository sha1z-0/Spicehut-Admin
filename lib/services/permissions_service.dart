import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class PermissionsService {
  /// Request runtime permissions in sequence so iOS shows native prompts one-by-one.
  static Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    final statuses = <Permission, PermissionStatus>{};

    for (final permission in _requiredPermissions()) {
      final currentStatus = await permission.status;

      if (currentStatus.isGranted || currentStatus.isLimited) {
        statuses[permission] = currentStatus;
        continue;
      }

      statuses[permission] = await permission.request();
    }

    return statuses;
  }

  /// Request individual permission
  static Future<bool> requestPermission(Permission permission) async {
    try {
      final status = await permission.request();
      return status.isGranted || status.isLimited;
    } catch (e) {
      return false;
    }
  }

  /// Check if permission is granted
  static Future<bool> isPermissionGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted || status.isLimited;
  }

  /// Check if multiple permissions are granted
  static Future<bool> arePermissionsGranted(List<Permission> permissions) async {
    for (final permission in permissions) {
      if (!await isPermissionGranted(permission)) {
        return false;
      }
    }
    return true;
  }

  static List<Permission> _requiredPermissions() {
    if (!kIsWeb && Platform.isIOS) {
      return [
        Permission.camera,
        Permission.photos,
      ];
    }

    if (!kIsWeb && Platform.isAndroid) {
      return [
        Permission.camera,
        Permission.storage,
      ];
    }

    return [Permission.camera];
  }

  /// Check and request camera permission
  static Future<bool> requestCameraPermission() async {
    return await requestPermission(Permission.camera);
  }

  /// Check and request media library/storage permission based on platform.
  static Future<bool> requestStoragePermission() async {
    if (!kIsWeb && Platform.isIOS) {
      return await requestPermission(Permission.photos);
    }
    return await requestPermission(Permission.storage);
  }

  /// Open app settings for user to manually enable permissions
  static Future<void> openAppSettingsPage() async {
    await openAppSettings();
  }
}
