import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../../data/models/user_role.dart';
import '../../widgets/logout_confirmation_dialog.dart';
import '../../widgets/primary_button.dart';
import '../auth/login_screen.dart';
import 'app_info_screen.dart';
import 'attendance_mock_store.dart';
import 'child_info_screen.dart';
import 'notification_settings_screen.dart';
import '../auth/change_password_screen.dart';

// 출석·결석 설정: 결석이면 탑승 예정 인원에서 빠져 오경고 감소
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Map<String, bool> _absent;

  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<ChildStudent> _children = [];
  final Map<int, bool> _apiAbsent = {};

  String _accountRoleLabel() {
    final code = Session.accountRole?.toUpperCase();
    return switch (code) {
      'ADMIN' => '관리자',
      'DRIVER' => '기사',
      'PARENT' => '학부모',
      _ => switch (Session.role) {
        UserRole.driver => '기사',
        UserRole.parent => '학부모',
        null => '정보 없음',
      },
    };
  }

  @override
  void initState() {
    super.initState();
    _absent = AttendanceMockStore.getAttendance(_selectedDate);
    _loadChildren();
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _absent = AttendanceMockStore.getAttendance(date);
    });
  }

  void _saveAttendance() {
    AttendanceMockStore.saveForDate(_selectedDate, _absent);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_formatDate(_selectedDate)} 출석·결석 정보가 저장되었습니다'),
      ),
    );

    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final children = await ApiRepository.instance.getChildren();
      if (!mounted) return;

      setState(() {
        _children = children;
        _apiAbsent
          ..clear()
          ..addEntries(children.map((child) => MapEntry(child.id, child.isAbsent)));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '자녀 정보를 불러오지 못했습니다. 다시 시도해 주세요.';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      for (final child in _children) {
        await ApiRepository.instance.setChildAttendance(
          child,
          isAbsent: _apiAbsent[child.id] ?? false,
          date: _selectedDate,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출석 상태를 저장했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('출석 상태를 저장하지 못했습니다. ($e)')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final isToday =
        _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Session.name?.isNotEmpty == true
                                        ? Session.name!
                                        : '계정 정보 없음',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    Session.email?.isNotEmpty == true
                                        ? Session.email!
                                        : '이메일 정보 없음',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _accountRoleLabel(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        minVerticalPadding: 14,
                        leading: const Icon(Icons.person_outline_rounded, color: Colors.blue),
                        title: const Text(
                          '계정 정보',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('이름, 이메일, 계정 생성일 및 유형을 조회합니다.'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ParentAccountInfoScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '출석·결석 관리',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '스위치 ON: 등교 / OFF: 결석',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '신청 날짜',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('오늘'),
                            selected: isToday,
                            onSelected: (_) => _selectDate(today),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('내일'),
                            selected: !isToday,
                            onSelected: (_) => _selectDate(tomorrow),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '선택한 날짜: ${_formatDate(_selectedDate)}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          for (final name in _absent.keys)
                            SwitchListTile(
                              title: Text(name),
                              subtitle: Text(_absent[name]! ? '결석' : '등교'),
                              value: !_absent[name]!,
                              onChanged: (v) {
                                setState(() {
                                  _absent[name] = !v;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '자녀 관리',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.people_outline, color: Colors.blue),
                        title: const Text('자녀 정보'),
                        subtitle: const Text('등록된 자녀 및 배정 버스 확인'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ChildInfoScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '알림 관리',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.notifications_none, color: Colors.orange),
                        title: const Text('알림 설정'),
                        subtitle: const Text('승하차 및 안전 알림 관리'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NotificationSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '기타',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info_outline, color: Colors.grey),
                        title: const Text('앱 정보'),
                        subtitle: const Text('서비스 소개 및 테스트 버전 안내'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AppInfoScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '서버 연동 출석 관리',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else if (_error != null)
                      Column(
                        children: [
                          Text(_error!),
                          OutlinedButton(
                            onPressed: _loadChildren,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      )
                    else if (_children.isEmpty)
                      const Text('연결된 자녀가 없습니다.')
                    else
                      ..._children.map(
                        (child) => SwitchListTile(
                          title: Text(child.name),
                          subtitle: Text(child.className ?? '결석 여부'),
                          value: _apiAbsent[child.id] ?? false,
                          onChanged: (value) => setState(() => _apiAbsent[child.id] = value),
                        ),
                      ),
                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: '서버에 저장',
                      loading: _saving,
                      onPressed: _saving || _loading || _error != null || _children.isEmpty ? null : _save,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final shouldLogout = await showLogoutConfirmationDialog(context);
                  if (!shouldLogout || !context.mounted) return;
                  await Session.clear();
                  if (!context.mounted) return;
                  Navigator.of(context, rootNavigator: true).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text(
                  '로그아웃',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: '저장',
                onPressed: _saveAttendance,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ParentAccountInfoScreen extends StatelessWidget {
  const ParentAccountInfoScreen({super.key});

  String _formatCreatedAt(DateTime? createdAt) {
    if (createdAt == null) return '정보 없음';
    final date = createdAt.toLocal();
    return '${date.year}년 ${date.month}월 ${date.day}일 '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _accountRoleLabel() {
    final code = Session.accountRole?.toUpperCase();
    return switch (code) {
      'ADMIN' => '관리자',
      'DRIVER' => '기사',
      'PARENT' => '학부모',
      _ => switch (Session.role) {
        UserRole.driver => '기사',
        UserRole.parent => '학부모',
        null => '정보 없음',
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 정보')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '계정 상세 정보',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.blue,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                _AccountInfoRow(
                  label: '사용자 이름',
                  value: Session.name?.isNotEmpty == true ? Session.name! : '정보 없음',
                  icon: Icons.badge_outlined,
                ),
                _AccountInfoRow(
                  label: '이메일',
                  value: Session.email?.isNotEmpty == true ? Session.email! : '정보 없음',
                  icon: Icons.email_outlined,
                ),
                _AccountInfoRow(
                  label: '계정 생성일',
                  value: _formatCreatedAt(Session.createdAt),
                  icon: Icons.calendar_today_outlined,
                ),
                _AccountInfoRow(
                  label: '계정 유형',
                  value: _accountRoleLabel(),
                  icon: Icons.admin_panel_settings_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_reset_rounded, color: Colors.blue),
              title: const Text('비밀번호 변경하기'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
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
