import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../../data/models/user_role.dart';
import '../../widgets/primary_button.dart';
import '../auth/change_password_screen.dart';
import '../auth/login_screen.dart';
import '../auth/account_removal_screen.dart';
import 'guardian_location_screen.dart';
import '../../widgets/logout_confirmation_dialog.dart';

// 출석·결석 관리: 날짜별 등교/결석 상태를 설정
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<ChildStudent> _children = [];
  final Map<int, bool> _apiAbsent = {};

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _loadChildren(date: date);
  }

  Future<void> _loadChildren({DateTime? date}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final children = await ApiRepository.instance.getChildren(
        date: date ?? _selectedDate,
      );
      if (!mounted) return;

      setState(() {
        _children = children;
        _apiAbsent
          ..clear()
          ..addEntries(
            children.map((child) => MapEntry(child.id, child.isAbsent)),
          );
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

      await _loadChildren(date: _selectedDate);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('출석 상태를 저장했습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('출석 상태를 저장하지 못했습니다. ($e)')));
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
      appBar: AppBar(title: const Text('출석·결석 관리')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 16),
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
                      style: TextStyle(color: Colors.grey, fontSize: 13),
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
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '자녀별 출석 상태',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                          onChanged: (value) =>
                              setState(() => _apiAbsent[child.id] = value),
                        ),
                      ),
                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: '저장',
                      loading: _saving,
                      onPressed:
                          _saving ||
                              _loading ||
                              _error != null ||
                              _children.isEmpty
                          ? null
                          : _save,
                    ),
                  ],
                ),
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
                color: Colors.black,
              ),
            ),
          ),
          Card(
            shape: const RoundedRectangleBorder(
              side: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Column(
              children: [
                _AccountInfoRow(
                  label: '사용자 이름',
                  value: Session.name?.isNotEmpty == true
                      ? Session.name!
                      : '정보 없음',
                  icon: Icons.badge_outlined,
                ),
                _AccountInfoRow(
                  label: '이메일',
                  value: Session.email?.isNotEmpty == true
                      ? Session.email!
                      : '정보 없음',
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
            shape: const RoundedRectangleBorder(
              side: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('보호자 주소 및 위치'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GuardianLocationScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: const RoundedRectangleBorder(
              side: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.lock_reset_rounded,
                color: Colors.black,
              ),
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
          const SizedBox(height: 12),
          Card(
            shape: const RoundedRectangleBorder(
              side: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text(
                '로그아웃',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                final shouldLogout = await showLogoutConfirmationDialog(
                  context,
                );
                if (!shouldLogout || !context.mounted) return;
                await Session.clear();
                if (!context.mounted) return;
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: const RoundedRectangleBorder(
              side: BorderSide.none,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.person_remove_alt_1_rounded,
                color: Colors.red,
              ),
              title: const Text(
                '계정 삭제',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AccountRemovalScreen(),
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
          Icon(icon, color: Colors.black, size: 22),
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
