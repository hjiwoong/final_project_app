import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/app_error_message.dart';
import '../../core/auth/session.dart';
import '../../core/permissions/camera_permission_service.dart';
import '../../data/api/api_repository.dart';
import '../../widgets/primary_button.dart';
import 'judge_result_screen.dart';

import '../../core/notifications/in_app_notification_banner.dart';

/// ④ 종점 촬영: POST /trips/{id}/dropoff-photo → 잔류 카운트 · 판정
class DropoffCaptureScreen extends StatefulWidget {
  const DropoffCaptureScreen({super.key});

  @override
  State<DropoffCaptureScreen> createState() => _DropoffCaptureScreenState();
}

class _DropoffCaptureScreenState extends State<DropoffCaptureScreen> {
  bool _loading = false;

  Future<void> _captureFromSource(ImageSource source) async {
    if (source == ImageSource.camera &&
        !await CameraPermissionService.requestAccess(context)) {
      return;
    }
    final tripId = Session.currentTripId;
    if (tripId == null) {
      InAppNotificationBanner.showMessage('진행 중인 운행 정보를 찾을 수 없습니다. 운행을 다시 시작해 주세요.');
      return;
    }
    setState(() => _loading = true);
    try {
      final image = await ApiRepository.instance.pickImage(source: source);
      if (image == null) {
        if (!mounted) return;
        InAppNotificationBanner.showMessage('촬영을 취소했습니다.');
        return;
      }

      final result = await ApiRepository.instance.uploadDropoffPhoto(
        tripId,
        image: image,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => JudgeResultScreen(result: result)),
      );
    } catch (e) {
      if (!mounted) return;
      InAppNotificationBanner.showMessage(
        AppErrorMessage.from(e, fallback: '종점 처리를 완료하지 못했습니다. 다시 시도해 주세요.'),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 촬영 버튼: 사진 앱 선택 없이 바로 카메라 (운행 중 실제 차량 사진만 쓰도록)
  Future<void> _choosePhoto() async {
    await _captureFromSource(ImageSource.camera);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(''),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Icon(
                          Icons.photo_camera,
                          size: 96,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 5),
                      Center(
                        child: Text(
                          '종점 인원 촬영',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '모든 탑승객이 하차했는지 확인하기 위해 사진을 선택합니다.\n'
                        '카메라로 찍은 버스 내부 사진을 서버의 YOLO 모델로 분석합니다.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                '사진은 서버에 전송됩니다. 인원 확인 목적으로만 사용되며\n전송을 거부할 순 있지만 이 경우 운행을 종료할 수 없습니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: '종점 사진 촬영',
                loading: _loading,
                onPressed: _choosePhoto,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
