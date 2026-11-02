import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/auth/trip_progress_storage.dart';
import '../../data/api/api_repository.dart';
import '../../widgets/primary_button.dart';
import 'dropoff_capture_screen.dart';

/// ③ 승차 촬영: POST /trips/{id}/boarding-photo → YOLO 승차 인원
class BoardingCaptureScreen extends StatefulWidget {
  const BoardingCaptureScreen({super.key});

  @override
  State<BoardingCaptureScreen> createState() => _BoardingCaptureScreenState();
}

class _BoardingCaptureScreenState extends State<BoardingCaptureScreen> {
  bool _loading = false;
  int? _count = Session.currentBoardingCount;

  Future<void> _capture() async {
    setState(() => _loading = true);
    try {
      final count = await ApiRepository.instance.uploadBoardingPhoto(
        Session.currentTripId ?? 1,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('승차 처리를 완료하지 못했습니다. ($e)')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      setState(() => _count = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('재촬영 상태를 저장하지 못했습니다. ($e)')));
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('승차 인원 결과는 표시되지만 복구 정보 저장에 실패했습니다. ($error)')),
    );
  }

  void _showFullImage() {
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
              child: Image.asset(
                'assets/images/testimages/boarding_image.jpg',
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
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
                '승차 사진에서 YOLO를 이용해 버스에 탑승하고 있는 승객을 탐지해 총 탑승 인원을 산출합니다. '
                '촬영 환경에 따라 실제 인원과 분석 결과가 다를 수 있습니다.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.grey.shade700,
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
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
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_camera,
                            size: 96,
                            color: Colors.grey,
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
                            '탑승객이 모두 보이도록 촬영을 시작합니다.\n차량 내부의 카메라가 필요합니다. 카메라가 없는 경우 운행하려는 버스에 카메라가 설치되어 있는지 확인합니다.',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 14, color: Colors.grey),
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
                            GestureDetector(
                              onTap: _showFullImage,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                clipBehavior: Clip.antiAlias,
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Image.asset(
                                    'assets/images/testimages/boarding_image.jpg',
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
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
                                  icon: const Icon(
                                    Icons.info_outline,
                                    color: Colors.grey,
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
                  const Text(
                    '사진은 서버에 전송됩니다. 인원 확인 목적으로만 사용되며\n전송을 거부할 순 있지만 이 경우 운행을 진행할 수 없습니다.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: '승차 촬영',
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF202329),
                          side: const BorderSide(color: Color(0xFFD8DADD)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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
