import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';
import '../../widgets/primary_button.dart';
import 'judge_result_screen.dart';

/// ④ 종점 촬영: POST /trips/{id}/dropoff-photo → 잔류 카운트 · 판정
/// mock 단계에서는 시연 시나리오 두 가지를 버튼으로 고름
class DropoffCaptureScreen extends StatefulWidget {
  const DropoffCaptureScreen({super.key});

  @override
  State<DropoffCaptureScreen> createState() => _DropoffCaptureScreenState();
}

class _DropoffCaptureScreenState extends State<DropoffCaptureScreen> {
  bool _loading = false;

  Future<void> _capture({required bool oneRemaining}) async {
    setState(() => _loading = true);
    try {
      final tripId = Session.currentTripId ?? 1;
      final result = await ApiRepository.instance.uploadDropoffPhoto(
        tripId,
        oneRemaining: oneRemaining,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => JudgeResultScreen(result: result)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('종점 처리를 완료하지 못했습니다. ($e)')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('종점 촬영'),
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
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Icon(
                        Icons.photo_camera,
                        size: 96,
                        color: Colors.grey,
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
                      '모든 탑승객이 하차했는지 확인하기 위해 촬영을 시작합니다.\n'
                      '차량 내부에 남아 있는 승객이 없는지 확인해 주세요.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const Text(
              '사진은 서버에 전송됩니다. 인원 확인 목적으로만 사용되며\n전송을 거부할 순 있지만 이 경우 운행을 종료할 수 없습니다.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: '종점 촬영 (전원 하차) - 개발용',
              loading: _loading,
              onPressed: () => _capture(oneRemaining: false),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: '종점 촬영 (1명 남음) - 개발용',
              color: AppTheme.danger,
              loading: _loading,
              onPressed: () => _capture(oneRemaining: true),
            ),
          ],
        ),
      ),
    );
  }
}
