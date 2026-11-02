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
  final String busName;

  const TripEndScreen({super.key, required this.result, required this.busName});

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
      Session.currentTripBusName = null;
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
    final statusColor = result.isOk ? AppTheme.ok : AppTheme.danger;
    return Scaffold(
      appBar: AppBar(title: const Text('운행 결과')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.subtleSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    result.isOk
                        ? Icons.directions_bus_rounded
                        : Icons.warning_amber_rounded,
                    color: statusColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.busName,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          result.isOk ? '하차 확인 완료' : '미하차 있음',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '탑승 인원 요약',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.subtleSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _TripCountRow(
                  label: '승차',
                  count: result.boardingCount,
                  icon: Icons.login_rounded,
                ),
                _TripCountRow(
                  label: '잔류',
                  count: result.remainingCount,
                  icon: Icons.person_outline_rounded,
                  color: result.remainingCount == 0
                      ? AppTheme.ok
                      : AppTheme.danger,
                ),
                _TripCountRow(
                  label: '하차',
                  count: result.alightedCount,
                  icon: Icons.logout_rounded,
                ),
              ],
            ),
          ),
          if (!result.isOk) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.danger,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '미하차 인원이 있어 운행을 종료할 수 없습니다. 차량 내부를 확인하세요.'
                      '\n\n미하차에 대한 운행 결과는 운행 기록에 저장됩니다.',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: PrimaryButton(
            label: '하차 확인 완료',
            loading: _isConfirming,
            onPressed: result.isOk ? _confirmTrip : null,
          ),
        ),
      ),
    );
  }
}

class _TripCountRow extends StatelessWidget {
  const _TripCountRow({
    required this.label,
    required this.count,
    required this.icon,
    this.color = AppTheme.primary,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
          ),
        ),
        Text(
          '$count명',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
