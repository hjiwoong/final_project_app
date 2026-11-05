import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/session.dart';
import '../../core/auth/trip_progress_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';
import '../../widgets/primary_button.dart';
import 'dropoff_capture_screen.dart';

import '../../core/notifications/in_app_notification_banner.dart';

/// ③ 승차 촬영: POST /trips/{id}/boarding-photo → YOLO 승차 인원
class BoardingCaptureScreen extends StatefulWidget {
  const BoardingCaptureScreen({super.key});

  @override
  State<BoardingCaptureScreen> createState() => _BoardingCaptureScreenState();
}

class _BoardingCaptureScreenState extends State<BoardingCaptureScreen> {
  bool _loading = false;
  int? _count = Session.currentBoardingCount;
  XFile? _selectedImage;

  Future<void> _captureFromSource(ImageSource source) async {
    setState(() => _loading = true);
    try {
      final image = await ApiRepository.instance.pickImage(source: source);
      if (image == null) {
        if (!mounted) return;
        InAppNotificationBanner.showMessage('사진 선택을 취소했습니다.');
        return;
      }

      setState(() => _selectedImage = image);

      final count = await ApiRepository.instance.uploadBoardingPhoto(
        Session.currentTripId ?? 1,
        image: image,
      );
      if (!mounted) return;
      Session.currentBoardingCount = count;
      setState(() => _count = count);
      try {
        await _saveBoardingCount(count);
      } catch (e) {
        await _showBoardingSaveError(e);
      }
    } catch (e) {
      if (!mounted) return;
      InAppNotificationBanner.showMessage('승차 처리를 완료하지 못했습니다. ($e)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: AppTheme.sheetMargin,
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.sheetDecoration(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '사진 선택',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('카메라로 촬영'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('사진 앱에서 선택'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;
    await _captureFromSource(source);
  }

  Future<void> _capture() async {
    await _choosePhoto();
  }

  void _retake() {
    _clearSavedBoardingCount();
  }

  Future<void> _clearSavedBoardingCount() async {
    try {
      final progress = await TripProgressStorage.read();
      if (progress == null) {
        throw StateError('진행 중인 운행 정보를 찾을 수 없습니다.');
      }
      await TripProgressStorage.save(
        progress.copyWith(clearBoardingCount: true),
      );
      if (!mounted) return;
      Session.currentBoardingCount = null;
      setState(() {
        _count = null;
        _selectedImage = null;
      });
    } catch (e) {
      if (!mounted) return;
      InAppNotificationBanner.showMessage('재촬영 상태를 저장하지 못했습니다. ($e)');
    }
  }

  Future<void> _saveBoardingCount(int count) async {
    final progress = await TripProgressStorage.read();
    if (progress == null) {
      throw StateError('진행 중인 운행 정보를 찾을 수 없습니다.');
    }
    await TripProgressStorage.save(progress.copyWith(boardingCount: count));
  }

  Future<void> _showBoardingSaveError(Object error) async {
    if (!mounted) return;
    InAppNotificationBanner.showMessage(
      '승차 인원 결과는 표시되지만 복구 정보 저장에 실패했습니다. ($error)',
    );
  }

  void _showFullImage() {
    if (_selectedImage == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.file(
                File(_selectedImage!.path),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAnalysisInfo() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          margin: AppTheme.sheetMargin,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          decoration: AppTheme.sheetDecoration(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '분석 방식',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: '닫기',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '승차 사진에서 YOLO 모델을 이용해 버스에 탑승하고 있는 승객을 탐지해 총 탑승 인원을 산출합니다. '
                '촬영 환경에 따라 실제 인원과 분석 결과가 다를 수 있습니다.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDropoffNavigation() async {
    final shouldContinue = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          margin: AppTheme.sheetMargin,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          decoration: AppTheme.sheetDecoration(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '종점 도착',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                '종점으로 도착했다면 예를 탭하세요, 아직 도착하지 않았다면 아니요를 탭합니다.\n예를 선택하면 돌아갈 수 없습니다.',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('아니요'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('예'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldContinue != true || !mounted) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DropoffCaptureScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        leading: IconButton(
          tooltip: '뒤로가기',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: _count == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_camera,
                            size: 96,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(height: 1),
                          Text(
                            '승차 인원 촬영',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '탑승객이 모두 보이도록 사진을 선택합니다.\n카메라 또는 사진 앱에서 버스 내부 이미지를 가져와 분석합니다.\n\n권한을 거부한 경우 설정에서 변경할 수 있습니다.',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectedImage != null)
                              GestureDetector(
                                onTap: _showFullImage,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  clipBehavior: Clip.antiAlias,
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Image.file(
                                      File(_selectedImage!.path),
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '총 탑승 인원: $_count명',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '분석 방식 안내',
                                  onPressed: _showAnalysisInfo,
                                  icon: Icon(
                                    Icons.info_outline,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            if (_count == null)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '사진은 서버에 전송됩니다. 인원 확인 목적으로만 사용되며\n전송을 거부할 순 있지만 이 경우 운행을 진행할 수 없습니다.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: '승차 사진 선택',
                    loading: _loading,
                    onPressed: _capture,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _retake,
                        child: const Text(
                          '재촬영',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: '종점으로 이동',
                      onPressed: _confirmDropoffNavigation,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
