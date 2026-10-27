import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../auth/child_link_request_screen.dart';
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
        children: [
          Card(
            color: const Color(0xFFF1F6FF),
            elevation: 0,
            child: ListTile(
              leading: const Icon(
                Icons.family_restroom_rounded,
                color: Color(0xFF3B82F6),
              ),
              title: const Text(
                '자녀 연결 요청',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('자녀 정보를 계정에 추가해 주세요.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                final email = Session.email;
                if (email == null || email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그인한 계정 정보를 확인할 수 없습니다.')),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChildLinkRequestScreen(email: email),
                  ),
                );
              },
            ),
          ),
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
