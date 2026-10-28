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
      appBar: AppBar(title: const Text('종점 촬영')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Expanded(
              child: Center(
                child: Icon(Icons.photo_camera, size: 96, color: Colors.grey),
              ),
            ),
            PrimaryButton(
              label: '종점 촬영 (전원 하차)',
              loading: _loading,
              onPressed: () => _capture(oneRemaining: false),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: '종점 촬영 (1명 남음)',
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
