import 'package:flutter/material.dart';

/// 설정·계정 화면에서 공통으로 쓰는 메뉴 한 줄. 상하좌우 여백과 높이를 통일한다.
class SettingsMenuTile extends StatelessWidget {
  const SettingsMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  /// 로그아웃·계정 삭제처럼 강조할 때 아이콘과 글자 색.
  final Color? color;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        side: BorderSide.none,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        minVerticalPadding: 0,
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
        trailing: showChevron
            ? Icon(Icons.chevron_right_rounded, color: color)
            : null,
        onTap: onTap,
      ),
    );
  }
}
