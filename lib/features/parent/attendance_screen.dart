import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';
import '../../widgets/primary_button.dart';
import 'attendance_mock_store.dart';
import 'notification_settings_screen.dart';
import 'child_info_screen.dart';
import 'app_info_screen.dart';

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

@override
void initState() {
super.initState();


_absent = AttendanceMockStore.getAttendance(_selectedDate);
_loadChildren();
}

// 날짜 표시
String _formatDate(DateTime date) {
return '${date.year}년 ${date.month}월 ${date.day}일';
}

// 오늘 또는 내일 선택
void _selectDate(DateTime date) {
setState(() {
_selectedDate = date;
_absent = AttendanceMockStore.getAttendance(date);
});
}

// 결석 정보 저장
void _saveAttendance() {
AttendanceMockStore.saveForDate(
_selectedDate,
_absent,
);

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(
'${_formatDate(_selectedDate)} 출석·결석 정보가 저장되었습니다',
),
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
if (mounted) setState(() => _saving = false);
}
}

@override
Widget build(BuildContext context) {
final today = DateTime.now();

final tomorrow = DateTime(
today.year,
today.month,
today.day + 1,
);

final isToday =
_selectedDate.year == today.year &&
_selectedDate.month == today.month &&
_selectedDate.day == today.day;

return Scaffold(
appBar: AppBar(
title: const Text('설정'),
),
body: Padding(
padding: const EdgeInsets.all(16),

child: Column(
children: [
Expanded(
child: ListView(
children: [
// 출석·결석 관리
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

// 날짜 선택
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
onSelected: (_) {
_selectDate(today);
},
),
),

const SizedBox(width: 12),

Expanded(
child: ChoiceChip(
label: const Text('내일'),
selected: !isToday,
onSelected: (_) {
_selectDate(tomorrow);
},
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

// 자녀별 출석·결석
Card(
child: Column(
children: [
for (final name in _absent.keys)
SwitchListTile(
title: Text(name),
subtitle: Text(
_absent[name]!
? '결석'
    : '등교',
),
// ON = 등교 / OFF = 결석
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

// 자녀 정보
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
leading: const Icon(
Icons.people_outline,
color: Colors.blue,
),
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

// 알림 설정
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
leading: const Icon(
Icons.notifications_none,
color: Colors.orange,
),
title: const Text('알림 설정'),
subtitle: const Text('승하차 및 안전 알림 관리'),
trailing: const Icon(Icons.chevron_right),
onTap: () {
Navigator.of(context).push(
MaterialPageRoute(
builder: (_) =>
const NotificationSettingsScreen(),
),
);
},
),
),

const SizedBox(height: 24),

// 앱 정보
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
leading: const Icon(
Icons.info_outline,
color: Colors.grey,
),
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

const SizedBox(height: 16),
const SizedBox(height: 24),
const Text('서버 연동 출석 관리', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
const SizedBox(height: 8),
if (_loading)
const Center(child: CircularProgressIndicator())
else if (_error != null)
Column(
children: [
Text(_error!),
OutlinedButton(onPressed: _loadChildren, child: const Text('다시 시도')),
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

// 기존 저장 버튼 유지
const SizedBox(height: 12),

PrimaryButton(
label: '저장',
onPressed: _saveAttendance,
),
],
),
),
);
}
}
