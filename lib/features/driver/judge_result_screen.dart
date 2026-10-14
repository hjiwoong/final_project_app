import 'package:flutter/material.dart';

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
            Card(
              color: ok ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      ok ? '✅ 하차 확인 완료' : '🚨 미하차 의심 ${result.remainingCount}명',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: ok ? AppTheme.ok : AppTheme.danger,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('승차 ${result.boardingCount} · 잔류 ${result.remainingCount} · 하차 ${result.alightedCount}'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (!ok) ...[
              PrimaryButton(label: '재촬영', onPressed: () => Navigator.of(context).pop()),
              const SizedBox(height: 12),
            ],
            PrimaryButton(
              label: '운행 종료로',
              color: ok ? null : Colors.grey,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TripEndScreen(result: result)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
