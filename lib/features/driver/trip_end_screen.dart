import 'package:flutter/material.dart';

import '../../core/errors/app_error_message.dart';
import '../../core/auth/session.dart';
import '../../core/auth/trip_progress_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/judge_result.dart';
import '../../widgets/primary_button.dart';
import 'driver_shell.dart';

import '../../core/notifications/in_app_notification_banner.dart';

/// ⑥ 운행 종료: POST /trips/{id}/confirm
class TripEndScreen extends StatefulWidget {
  final JudgeResult result;
  final String busName;

  const TripEndScreen({super.key, required this.result, required this.busName});

  @override
  State<TripEndScreen> createState() => _TripEndScreenState();
}

class _TripEndScreenState extends State<TripEndScreen> {
  bool _isConfirming = false;

  Future<void> _confirmTrip({String? reason}) async {
    final tripId = Session.currentTripId;
    if (tripId == null || _isConfirming) return;

    setState(() => _isConfirming = true);
    try {
      await ApiRepository.instance.confirmTrip(tripId, reason: reason);
      await TripProgressStorage.clear();
      Session.currentTripId = null;
      Session.currentTripBusName = null;
      Session.currentBoardingCount = null;
      if (!mounted) return;

      InAppNotificationBanner.showMessage('운행이 종료되었습니다');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DriverShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      InAppNotificationBanner.showMessage(
        AppErrorMessage.from(e, fallback: '운행 종료를 완료하지 못했습니다. 다시 시도해 주세요.'),
      );
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  Future<void> _showRemainingReasonSheet() async {
    final controller = TextEditingController();
    String? validationMessage;
    final isNeedsCheck = widget.result.isNeedsCheck;

    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Container(
                margin: AppTheme.sheetMargin,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                decoration: AppTheme.sheetDecoration(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNeedsCheck ? '확인 필요 사유 입력' : '미하차 사유 입력',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isNeedsCheck
                          ? '사진 판정을 확정할 수 없는 상태에서 운행을 종료하려는 사유를 입력해 주세요. '
                                '\n입력한 내용은 관리자에게 전달됩니다.'
                          : '미하차 의심 상태에서 운행을 종료하려는 사유를 입력해 주세요. '
                                '\n입력한 내용은 관리자에게 전달됩니다.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: controller,
                      minLines: 3,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: '예: 보호자 인계 여부를 확인했으나 판정 오류로 잔류 인원 표시',
                        errorText: validationMessage,
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: '사유 제출 후 운행 종료',
                      onPressed: () {
                        final value = controller.text.trim();
                        if (value.isEmpty) {
                          setSheetState(
                            () => validationMessage = '운행 종료 사유를 입력해 주세요.',
                          );
                          return;
                        }
                        Navigator.of(context).pop(value);
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('취소'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    controller.dispose();

    if (reason != null && mounted) {
      await _confirmTrip(reason: reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = result.isOk
        ? colorScheme.tertiary
        : result.isNeedsCheck
        ? colorScheme.secondary
        : colorScheme.error;
    return Scaffold(
      appBar: AppBar(title: const Text('운행 결과')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    result.isOk
                        ? Icons.directions_bus_rounded
                        : Icons.warning_amber_rounded,
                    color: statusColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.busName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          result.isOk
                              ? '하차 확인 완료'
                              : result.isNeedsCheck
                              ? '확인 필요'
                              : '미하차 의심',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '탑승 인원 요약',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                _TripCountRow(
                  label: '승차',
                  count: result.boardingCount,
                  icon: Icons.login_rounded,
                ),
                _TripCountRow(
                  label: '잔류',
                  count: result.remainingCount,
                  icon: Icons.person_outline_rounded,
                  color: result.remainingCount == 0
                      ? AppTheme.ok
                      : AppTheme.danger,
                ),
                _TripCountRow(
                  label: '하차',
                  count: result.alightedCount,
                  icon: Icons.logout_rounded,
                ),
              ],
            ),
          ),
          if (!result.isOk) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: result.isNeedsCheck
                    ? colorScheme.secondaryContainer
                    : colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: result.isNeedsCheck
                      ? colorScheme.outlineVariant
                      : colorScheme.error,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: result.isNeedsCheck
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.error,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.isNeedsCheck
                          ? '사진이 어둡거나 검출 신뢰도가 낮아 판정을 확정할 수 없습니다. '
                                '가능하면 재촬영하거나 차량 내부를 직접 확인해 주세요.'
                          : '차량 내부를 직접 확인하고 필요한 조치를 완료한 뒤 운행을 종료하세요.',
                      style: TextStyle(
                        color: result.isNeedsCheck
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onErrorContainer,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: PrimaryButton(
            label: result.isOk ? '하차 확인 완료' : '확인 후 운행 종료',
            loading: _isConfirming,
            onPressed: result.isOk ? _confirmTrip : _showRemainingReasonSheet,
          ),
        ),
      ),
    );
  }
}

class _TripCountRow extends StatelessWidget {
  const _TripCountRow({
    required this.label,
    required this.count,
    required this.icon,
    this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ),
          Text(
            '$count명',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
