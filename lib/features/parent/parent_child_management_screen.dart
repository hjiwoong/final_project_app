import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../auth/child_link_request_screen.dart';
import '../../widgets/settings_menu_tile.dart';
import 'child_link_request_status_screen.dart';
import 'child_location_screen.dart';

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
            icon: Icons.location_on_outlined,
            title: '자녀 주소 및 위치',
            subtitle: '자녀의 승하차 주소와 위치를 관리합니다.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChildLocationScreen()),
            ),
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
  final String subtitle; // 메뉴 설명 (현재 화면에는 표시하지 않음)
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 설정 화면과 같은 공통 메뉴 줄 디자인 사용
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
  int? _unlinkingId;

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

  String _childStatus(ChildStudent child) {
    if (child.isAbsent) return '오늘 결석';
    return switch (child.busStatus) {
      'IN_PROGRESS' => '운행 중',
      'CLOSED' => '운행 완료',
      'NOT_STARTED' => '운행 전',
      'NOT_ASSIGNED' => '버스 미배정',
      _ => '상태 확인 불가',
    };
  }

  Future<bool> _confirmUnlink(ChildStudent child) async {
    if (_unlinkingId != null) return false;
    return await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) => SafeArea(
            top: false,
            child: Container(
              margin: AppTheme.sheetMargin,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: AppTheme.sheetDecoration(sheetContext),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          sheetContext,
                        ).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.link_off_outlined,
                        color: Theme.of(sheetContext).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '자녀 연결 해제',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${child.name} 자녀의 연결을 해제할까요?\n\n'
                    '이 계정과의 연결만 해제됩니다. 자녀 정보와 주소·위치 정보는 '
                    '삭제되지 않으며, 주소 삭제는 별도로 진행해야 합니다.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(
                        sheetContext,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                            ),
                            child: const Text('취소'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(true),
                            icon: const Icon(Icons.link_off_outlined),
                            label: const Text('연결 해제'),
                            style: FilledButton.styleFrom(
                              shape: const StadiumBorder(),
                              backgroundColor: Theme.of(
                                sheetContext,
                              ).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  Future<bool> _unlinkChild(ChildStudent child) async {
    if (!await _confirmUnlink(child) || !mounted) return false;

    setState(() => _unlinkingId = child.id);
    try {
      await ApiRepository.instance.unlinkChild(child);
      if (!mounted) return true;
      setState(() {
        _unlinkingId = null;
        _children = ApiRepository.instance.getChildren();
      });
      InAppNotificationBanner.showMessage('자녀 연결을 해제했습니다.');
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() => _unlinkingId = null);
      InAppNotificationBanner.showMessage('자녀 연결을 해제하지 못했습니다. 다시 시도해 주세요.');
      return false;
    }
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

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.swipe_left_alt_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '목록 항목을 왼쪽으로 밀어 연결을 해제할 수 있습니다.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: children.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final child = children[index];
                    final colors = Theme.of(context).colorScheme;
                    final isUnlinking = _unlinkingId == child.id;
                    final address = child.location?.address?.trim();
                    final status = _childStatus(child);
                    return Dismissible(
                      key: ValueKey(child.id),
                      direction: _unlinkingId == null
                          ? DismissDirection.endToStart
                          : DismissDirection.none,
                      confirmDismiss: (_) => _unlinkChild(child),
                      background: Container(
                        alignment: AlignmentDirectional.centerEnd,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: colors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '연결 해제',
                              style: TextStyle(
                                color: colors.onError,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.link_off_outlined,
                              color: colors.onError,
                            ),
                          ],
                        ),
                      ),
                      child: Card(
                        margin: EdgeInsets.zero,
                        shape: const RoundedRectangleBorder(
                          side: BorderSide.none,
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    child: Icon(Icons.person_outline),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          child.name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          child.className ?? '학급 정보 없음',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: colors.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isUnlinking)
                                    const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    Chip(
                                      label: Text(status),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: child.isAbsent
                                          ? colors.errorContainer
                                          : colors.primaryContainer,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 18,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      address == null || address.isEmpty
                                          ? '주소 미등록'
                                          : address,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color:
                                                address == null ||
                                                    address.isEmpty
                                                ? colors.onSurfaceVariant
                                                : null,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
