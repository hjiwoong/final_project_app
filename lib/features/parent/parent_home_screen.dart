import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../auth/login_screen.dart';

/// 학부모 홈: 오늘 자녀 탑승·하차 상태 (내 아이 정보만)
class ParentHomeScreen extends StatelessWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('학부모 홈'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Session.clear();
              Navigator.of(context, rootNavigator: true).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Card(
            child: ListTile(
              leading: Text('👧', style: TextStyle(fontSize: 28)),
              title: Text('김하늘'),
              subtitle: Text('1학년 2반'),
              trailing: Chip(label: Text('하차 완료')),
            ),
          ),
          Card(
            child: ListTile(
              leading: Text('👦', style: TextStyle(fontSize: 28)),
              title: Text('이도윤'),
              subtitle: Text('3학년 1반'),
              trailing: Chip(label: Text('탑승 중')),
            ),
          ),
        ],
      ),
    );
  }
}
