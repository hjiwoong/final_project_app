import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/judge_result.dart';
import '../../widgets/primary_button.dart';
import 'trip_start_screen.dart';

/// ⑥ 운행 종료: POST /trips/{id}/confirm · 결과 OK 아니면 409(종료 불가)
class TripEndScreen extends StatelessWidget {
  final JudgeResult result;

  const TripEndScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('운행 종료')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ListTile(
              title: const Text('1호차'),
              subtitle: Text('승차 ${result.boardingCount} / 하차 ${result.alightedCount}'),
              trailing: Text(
                result.isOk ? '정상' : '미하차 있음',
                style: TextStyle(color: result.isOk ? AppTheme.ok : AppTheme.danger),
              ),
            ),
            if (!result.isOk)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('🔒 미하차가 있어 운행을 종료할 수 없습니다. 차량 내부를 확인하세요.'),
              ),
            const Spacer(),
            PrimaryButton(
              label: '하차 확인 완료',
              onPressed: result.isOk
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('운행이 종료되었습니다 (CLOSED)')),
                      );
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const TripStartScreen()),
                        (route) => false,
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
