import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../widgets/primary_button.dart';
import '../auth/login_screen.dart';
import 'boarding_map_screen.dart';

/// ① 운행 시작: 버스 선택 · GET /trips/current
class TripStartScreen extends StatelessWidget {
  const TripStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('운행 시작'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Session.clear();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Card(
              child: ListTile(
                leading: Text('🚌', style: TextStyle(fontSize: 32)),
                title: Text('1호차 12가3456'),
                subtitle: Text('탑승 예정 학생 8명'),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.route),
                title: Text('노선'),
                subtitle: Text('○○초등학교 → 종점'),
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: '운행 시작',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BoardingMapScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
