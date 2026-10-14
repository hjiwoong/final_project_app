import 'package:flutter/material.dart';

import '../../widgets/primary_button.dart';

/// 출석·결석 설정: 결석이면 탑승 예정 인원에서 빠져 오경고 감소
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final Map<String, bool> _absent = {'김하늘': true, '이도윤': false};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('출석·결석')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final name in _absent.keys)
              SwitchListTile(
                title: Text(name),
                subtitle: const Text('오늘 결석'),
                value: _absent[name]!,
                onChanged: (v) => setState(() => _absent[name] = v),
              ),
            const Spacer(),
            PrimaryButton(
              label: '저장',
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('저장했습니다')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
