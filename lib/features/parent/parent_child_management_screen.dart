import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../auth/child_link_request_screen.dart';
import '../../widgets/settings_menu_tile.dart';
import 'child_link_request_status_screen.dart';
import 'child_unlink_screen.dart';

import '../../core/notifications/in_app_notification_banner.dart';

class ParentChildManagementScreen extends StatelessWidget {
  const ParentChildManagementScreen({super.key});

  Future<void> _openChildList(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _ChildListScreen()));
  }

  Future<void> _requestChildLink(BuildContext context) async {
    final email = Session.email;
    if (email == null || email.isEmpty) {
      InAppNotificationBanner.showMessage('계정 이메일 정보를 확인할 수 없습니다.');
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ChildLinkRequestScreen(email: email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('자녀 관리')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ChildManagementMenuTile(
            icon: Icons.format_list_bulleted,
            title: '자녀 목록 확인',
            subtitle: '계정에 연결된 자녀 정보를 확인합니다.',
            onTap: () => _openChildList(context),
          ),
          const SizedBox(height: 8),
          _ChildManagementMenuTile(
            icon: Icons.person_add_alt_1_outlined,
            title: '자녀 연결 요청',
            subtitle: '자녀 정보를 입력해 연결을 신청합니다.',
            onTap: () => _requestChildLink(context),
          ),
          const SizedBox(height: 8),
          _ChildManagementMenuTile(
            icon: Icons.pending_actions_outlined,
            title: '연결 요청 상태 확인',
            subtitle: '제출한 연결 요청의 처리 상태를 확인합니다.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ChildLinkRequestStatusScreen(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ChildManagementMenuTile(
            icon: Icons.link_off_outlined,
            title: '자녀 연결 해제',
            subtitle: '계정에 연결된 자녀의 연결을 해제합니다.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChildUnlinkScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildManagementMenuTile extends StatelessWidget {
  const _ChildManagementMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsMenuTile(icon: icon, title: title, onTap: onTap);
  }
}

class _ChildListScreen extends StatefulWidget {
  const _ChildListScreen();

  @override
  State<_ChildListScreen> createState() => _ChildListScreenState();
}

class _ChildListScreenState extends State<_ChildListScreen> {
  late Future<List<ChildStudent>> _children;

  @override
  void initState() {
    super.initState();
    _children = ApiRepository.instance.getChildren();
  }

  void _reloadChildren() {
    setState(() {
      _children = ApiRepository.instance.getChildren();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('자녀 목록 확인')),
      body: FutureBuilder<List<ChildStudent>>(
        future: _children,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 8),
                    const Text('자녀 정보를 불러오지 못했습니다.'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _reloadChildren,
                      icon: const Icon(Icons.refresh),
                      label: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            );
          }

          final children = snapshot.data ?? const <ChildStudent>[];
          if (children.isEmpty) {
            return const Center(child: Text('연결된 자녀가 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final child = children[index];
              return Card(
                shape: const RoundedRectangleBorder(
                  side: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(child.name),
                  subtitle: Text(child.className ?? '학급 정보 없음'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
