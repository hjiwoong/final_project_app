import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_student.dart';

import '../../core/notifications/in_app_notification_banner.dart';

class ChildUnlinkScreen extends StatefulWidget {
  const ChildUnlinkScreen({super.key});

  @override
  State<ChildUnlinkScreen> createState() => _ChildUnlinkScreenState();
}

class _ChildUnlinkScreenState extends State<ChildUnlinkScreen> {
  late Future<List<ChildStudent>> _children;
  int? _unlinkingId;

  @override
  void initState() {
    super.initState();
    _children = ApiRepository.instance.getChildren();
  }

  void _reload() {
    setState(() {
      _children = ApiRepository.instance.getChildren();
    });
  }

  Future<bool> _confirmUnlink(ChildStudent child) async {
    return await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => SafeArea(
            top: false,
            child: Container(
              margin: AppTheme.sheetMargin,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: AppTheme.sheetDecoration(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '자녀 연결 해제',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${child.name} 자녀와의 연결을 해제할까요? '
                    '학생 정보와 다른 보호자의 연결은 유지됩니다.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
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
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: FilledButton.styleFrom(
                              shape: const StadiumBorder(),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                            child: const Text('연결 해제'),
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

  Future<void> _unlink(ChildStudent child) async {
    if (!await _confirmUnlink(child) || !mounted) return;
    setState(() => _unlinkingId = child.id);
    try {
      await ApiRepository.instance.unlinkChild(child);
      if (!mounted) return;
      setState(() {
        _unlinkingId = null;
        _children = ApiRepository.instance.getChildren();
      });
      InAppNotificationBanner.showMessage('자녀 연결을 해제했습니다.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _unlinkingId = null);
      InAppNotificationBanner.showMessage('자녀 연결을 해제하지 못했습니다. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('자녀 연결 해제')),
      body: FutureBuilder<List<ChildStudent>>(
        future: _children,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('자녀 목록을 불러오지 못했습니다.'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                  ),
                ],
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
              final isUnlinking = _unlinkingId == child.id;
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
                  trailing: isUnlinking
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          onPressed: _unlinkingId == null
                              ? () => _unlink(child)
                              : null,
                          icon: const Icon(Icons.link_off_outlined),
                          tooltip: '연결 해제',
                          color: Theme.of(context).colorScheme.error,
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
