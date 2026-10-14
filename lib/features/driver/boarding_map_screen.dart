import 'package:flutter/material.dart';

import '../../widgets/primary_button.dart';
import 'boarding_capture_screen.dart';

/// ② 탑승 지도: 정류장 마커 + 학부모 출결 반영
/// TODO: 지도 SDK(google_maps_flutter / 네이버 지도) 연결
class BoardingMapScreen extends StatelessWidget {
  const BoardingMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stops = [
      ('1 박서연', '승차 완료', Colors.green),
      ('2 김하늘', '출석', Colors.red),
      ('3 이도윤', '결석', Colors.grey),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('탑승 지도')),
      body: Column(
        children: [
          Container(
            height: 220,
            width: double.infinity,
            color: const Color(0xFFE5EDF5),
            alignment: Alignment.center,
            child: const Text('지도 영역 (TODO)'),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final s in stops)
                  ListTile(
                    leading: Icon(Icons.location_on, color: s.$3),
                    title: Text(s.$1),
                    trailing: Text(s.$2),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('○○유치원 도착 · 탑승 5명 (결석 3명 제외)'),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: '탑승 완료',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BoardingCaptureScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
