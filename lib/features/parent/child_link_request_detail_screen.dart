import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/child_link_request.dart';

import '../../core/notifications/in_app_notification_banner.dart';

class ChildLinkRequestDetailScreen extends StatefulWidget {
  const ChildLinkRequestDetailScreen({required this.request, super.key});

  final ChildLinkRequest request;

  @override
  State<ChildLinkRequestDetailScreen> createState() =>
      _ChildLinkRequestDetailScreenState();
}

class _ChildLinkRequestDetailScreenState
    extends State<ChildLinkRequestDetailScreen> {
  bool _canceling = false;

  bool get _isPending => widget.request.status == 'PENDING';

  String _statusLabel(String status) => switch (status) {
    'PENDING' => '승인 대기',
    'APPROVED' => '승인 완료',
    'REJECTED' => '반려',
    _ => status,
  };

  String _formatDate(DateTime? date) {
    if (date == null) return '정보 없음';
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  Future<bool> _confirmCancel() async {
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
                    '연결 요청 취소',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.request.childName} 자녀의 연결 요청을 취소할까요?',
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
                            child: const Text('돌아가기'),
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
                            ),
                            child: const Text('요청 취소'),
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

  Future<void> _cancelRequest() async {
    if (!await _confirmCancel() || !mounted) return;
    setState(() => _canceling = true);
    try {
      await ApiRepository.instance.cancelChildRequest(widget.request);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _canceling = false);
      InAppNotificationBanner.showMessage(
        '요청을 취소하지 못했습니다. 상태를 새로고침한 후 다시 시도해 주세요.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Scaffold(
      appBar: AppBar(title: const Text('연결 요청 상세')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(label: '자녀 이름', value: request.childName),
                  if (request.className?.isNotEmpty == true)
                    _DetailRow(label: '학년 / 반', value: request.className!),
                  if (request.relation?.isNotEmpty == true)
                    _DetailRow(label: '관계', value: request.relation!),
                  _DetailRow(
                    label: '요청 상태',
                    value: _statusLabel(request.status),
                  ),
                  _DetailRow(
                    label: '신청일',
                    value: _formatDate(request.createdAt),
                  ),
                  if (request.decidedAt != null)
                    _DetailRow(
                      label: '처리일',
                      value: _formatDate(request.decidedAt),
                    ),
                  if (request.studentName?.isNotEmpty == true)
                    _DetailRow(label: '연결된 자녀', value: request.studentName!),
                  if (request.rejectReason?.isNotEmpty == true)
                    _DetailRow(label: '반려 사유', value: request.rejectReason!),
                ],
              ),
            ),
          ),
          if (_isPending) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _canceling ? null : _cancelRequest,
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: _canceling
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onError,
                        ),
                      )
                    : const Text('요청 취소'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
