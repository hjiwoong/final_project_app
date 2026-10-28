import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../../widgets/logout_confirmation_dialog.dart';
import '../auth/child_link_request_screen.dart';
import '../auth/login_screen.dart';

/// 학부모 홈: 오늘 자녀 탑승·하차 상태 (내 아이 정보만)
class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  late Future<List<ChildStudent>> _children;

  @override
  void initState() {
    super.initState();
    _children = ApiRepository.instance.getChildren();
  }

  void _reloadChildren() {
    setState(() => _children = ApiRepository.instance.getChildren());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('학부모 홈'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final shouldLogout = await showLogoutConfirmationDialog(context);
              if (!shouldLogout || !context.mounted) return;
              await Session.clear();
              if (!context.mounted) return;
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
          FutureBuilder<List<ChildStudent>>(
            future: _children,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('자녀 정보를 불러오지 못했습니다.'),
                    trailing: IconButton(
                      onPressed: _reloadChildren,
                      icon: const Icon(Icons.refresh),
                      tooltip: '다시 시도',
                    ),
                  ),
                );
              }

              return Column(
                children: snapshot.data!
                    .map(
                      (child) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.child_care),
                          title: Text(child.name),
                          subtitle: Text(child.className ?? '학급 정보 없음'),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
