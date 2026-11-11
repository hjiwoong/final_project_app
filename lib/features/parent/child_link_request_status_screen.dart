import 'package:flutter/material.dart';

import '../../data/api/api_repository.dart';
import '../../data/models/child_link_request.dart';
import 'child_link_request_detail_screen.dart';

class ChildLinkRequestStatusScreen extends StatefulWidget {
  const ChildLinkRequestStatusScreen({super.key});

  @override
  State<ChildLinkRequestStatusScreen> createState() =>
      _ChildLinkRequestStatusScreenState();
}

class _ChildLinkRequestStatusScreenState
    extends State<ChildLinkRequestStatusScreen> {
  late Future<List<ChildLinkRequest>> _requests;

  @override
  void initState() {
    super.initState();
    _requests = ApiRepository.instance.getChildRequests();
  }

  void _reload() {
    setState(() {
      _requests = ApiRepository.instance.getChildRequests();
    });
  }

  String _statusLabel(String status) => switch (status) {
    'PENDING' => '승인 대기',
    'APPROVED' => '승인 완료',
    'REJECTED' => '반려',
    _ => status,
  };

  Color _statusColor(BuildContext context, String status) => switch (status) {
    'APPROVED' => Theme.of(context).colorScheme.tertiary,
    'REJECTED' => Theme.of(context).colorScheme.error,
    _ => Theme.of(context).colorScheme.secondary,
  };

  String _formatDate(DateTime? date) {
    if (date == null) return '신청일 정보 없음';
    return '신청일 ${date.year}년 ${date.month}월 ${date.day}일';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('연결 요청 상태 확인'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: FutureBuilder<List<ChildLinkRequest>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _RequestLoadError(onRetry: _reload);
          }

          final requests = snapshot.data ?? const <ChildLinkRequest>[];
          if (requests.isEmpty) {
            return const Center(child: Text('확인할 연결 요청이 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final request = requests[index];
              final color = _statusColor(context, request.status);
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    request.childName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${request.className ?? '학급 정보 없음'} · ${_formatDate(request.createdAt)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(request.status),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () async {
                    final canceled = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            ChildLinkRequestDetailScreen(request: request),
                      ),
                    );
                    if (canceled == true && mounted) _reload();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestLoadError extends StatelessWidget {
  const _RequestLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            const Text('연결 요청 상태를 불러오지 못했습니다.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
