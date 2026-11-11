import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';
import '../notifications/in_app_notification_banner.dart';

class CameraPermissionService {
  CameraPermissionService._();

  static const _storage = FlutterSecureStorage();
  static const _denialCountKey = 'camera_permission_denial_count';

  static Future<bool> requestAccess(BuildContext context) async {
    final status = await Permission.camera.status;
    if (!context.mounted) return false;
    if (status.isGranted) {
      await _storage.delete(key: _denialCountKey);
      return true;
    }

    final denialCount =
        int.tryParse(await _storage.read(key: _denialCountKey) ?? '') ?? 0;
    if (!context.mounted) return false;
    if (status.isRestricted || status.isPermanentlyDenied || denialCount >= 2) {
      await _showSettingsSheet(context);
      return false;
    }

    final requestedStatus = await Permission.camera.request();
    if (!context.mounted) return false;
    if (requestedStatus.isGranted) {
      await _storage.delete(key: _denialCountKey);
      return true;
    }

    if (requestedStatus.isDenied) {
      final nextDenialCount = denialCount + 1;
      await _storage.write(
        key: _denialCountKey,
        value: nextDenialCount.toString(),
      );
      if (!context.mounted) return false;
      if (nextDenialCount >= 2) {
        await _showSettingsSheet(context);
      }
    } else if (requestedStatus.isPermanentlyDenied ||
        requestedStatus.isRestricted) {
      await _showSettingsSheet(context);
    }

    return false;
  }

  static Future<void> _showSettingsSheet(BuildContext context) async {
    final openSettings = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          margin: AppTheme.sheetMargin,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          decoration: AppTheme.sheetDecoration(sheetContext),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '카메라 권한이 필요합니다',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                '카메라 권한이 없거나 거부되었습니다. 기기 설정에서 카메라 권한을 허용한 뒤 다시 시도해 주세요.',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: const Text('나중에'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text('설정으로 이동'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (openSettings != true) return;
    final opened = await openAppSettings();
    if (!opened) {
      InAppNotificationBanner.showMessage(
        '설정을 열 수 없습니다. 기기 설정에서 카메라 권한을 직접 허용해 주세요.',
      );
    }
  }
}
