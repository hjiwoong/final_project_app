import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/judge_result.dart';
import '../../widgets/primary_button.dart';
import 'trip_end_screen.dart';

/// ⑤ 판정 결과: 정상 / 미하차 의심 / 재촬영
class JudgeResultScreen extends StatelessWidget {
  final JudgeResult result;

  const JudgeResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final ok = result.isOk;
    return Scaffold(
      appBar: AppBar(title: const Text('판정 결과 · 종점')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  'assets/images/testimages/boarding_image.jpg',
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ok ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ok ? '하차 확인 완료' : '미하차 의심 ${result.remainingCount}명',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ok ? AppTheme.ok : AppTheme.danger,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _CountSummary(
                          label: '승차',
                          count: result.boardingCount,
                          icon: Icons.login_rounded,
                        ),
                        _CountSummary(
                          label: '잔류',
                          count: result.remainingCount,
                          icon: Icons.person_outline_rounded,
                          color: result.remainingCount == 0
                              ? AppTheme.ok
                              : AppTheme.danger,
                        ),
                        _CountSummary(
                          label: '하차',
                          count: result.alightedCount,
                          icon: Icons.logout_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showAnalysisInfo(context),
                icon: const Icon(Icons.info_outline, size: 20),
                label: const Text('분석 및 동작 방법에 대해'),
              ),
            ),
            const Spacer(),
            if (!ok) ...[
              PrimaryButton(
                label: '재촬영',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 12),
            ],
            PrimaryButton(
              label: '운행 결과 확인',
              color: ok ? null : Colors.grey,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TripEndScreen(
                    result: result,
                    busName: Session.currentTripBusName ?? '운행 차량',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnalysisInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '분석 및 동작 방법',
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
                '승차 사진에서 확인한 인원과 종점 사진에서 감지한 잔류 인원을 비교합니다. '
                '하차 인원은 승차 인원에서 잔류 인원을 뺀 값입니다. '
                '잔류 인원이 있으면 차량 내부를 직접 확인한 뒤 재촬영해 주세요.'
                '\n\n분석 및 동작이 정상적으로 작동하지 않으면 관리자에게 문의하여 주시기 바랍니다.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountSummary extends StatelessWidget {
  const _CountSummary({
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
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
}
