import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
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
  int? _count;

  Future<void> _capture() async {
    setState(() => _loading = true);
    try {
      final count = await ApiRepository.instance.uploadBoardingPhoto(
        Session.currentTripId ?? 1,
      );
      if (!mounted) return;
      Session.currentBoardingCount = count;
      setState(() => _count = count);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('승차 처리를 완료하지 못했습니다. ($e)')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('승차 촬영')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _count == null
                    ? const Column(
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
                            '탑승객이 모두 보이도록 촬영해 주세요.\n 차량 내부의 카메라가 필요합니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'YOLO 승차 인원: $_count명',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            if (_count == null)
              PrimaryButton(
                label: '승차 촬영',
                loading: _loading,
                onPressed: _capture,
              )
            else
              PrimaryButton(
                label: '종점으로 이동',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DropoffCaptureScreen(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
