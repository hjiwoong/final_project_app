import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/auth/trip_progress_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/judge_result.dart';
import '../../widgets/primary_button.dart';
import 'driver_shell.dart';

/// ⑥ 운행 종료: POST /trips/{id}/confirm · 결과 OK 아니면 409(종료 불가)
class TripEndScreen extends StatefulWidget {
  final JudgeResult result;

  const TripEndScreen({super.key, required this.result});

  @override
  State<TripEndScreen> createState() => _TripEndScreenState();
}

class _TripEndScreenState extends State<TripEndScreen> {
  bool _isConfirming = false;

  Future<void> _confirmTrip() async {
    final tripId = Session.currentTripId;
    if (tripId == null || _isConfirming) return;

    setState(() => _isConfirming = true);
    try {
      final simulationMode = Session.currentTripSimulationMode;
      await ApiRepository.instance.confirmTrip(
        tripId,
        simulationMode: simulationMode,
        safetyChecked: !simulationMode,
      );
      await TripProgressStorage.clear();
      Session.currentTripId = null;
      Session.currentBoardingCount = null;
      Session.currentTripIsMock = false;
      Session.currentTripSimulationMode = false;
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('운행이 종료되었습니다')));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DriverShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('운행 종료를 완료하지 못했습니다. ($e)')));
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return Scaffold(
      appBar: AppBar(title: const Text('운행 종료')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ListTile(
              title: const Text('1호차'),
              subtitle: Text(
                '승차 ${result.boardingCount} / 하차 ${result.alightedCount}',
              ),
              trailing: Text(
                result.isOk ? '정상' : '미하차 있음',
                style: TextStyle(
                  color: result.isOk ? AppTheme.ok : AppTheme.danger,
                ),
              ),
            ),
            if (!result.isOk)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('미하차 인원이 있어 운행을 종료할 수 없습니다. 차량 내부를 확인하세요.'),
              ),
            const Spacer(),
            PrimaryButton(
              label: '하차 확인 완료',
              loading: _isConfirming,
              onPressed: result.isOk ? _confirmTrip : null,
            ),
          ],
        ),
      ),
    );
  }
}
