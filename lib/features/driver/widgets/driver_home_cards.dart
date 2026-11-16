import 'package:flutter/material.dart';

enum HomeTopCardState { activeTrip, nextTrip, empty }

HomeTopCardState resolveHomeTopCardState({
  required bool hasActiveTrip,
  required bool hasAssignedBuses,
}) {
  if (hasActiveTrip) return HomeTopCardState.activeTrip;
  if (hasAssignedBuses) return HomeTopCardState.nextTrip;
  return HomeTopCardState.empty;
}

class ActiveTripCard extends StatelessWidget {
  const ActiveTripCard({
    super.key,
    required this.title,
    required this.onResume,
    required this.onEnd,
    this.elapsedTime,
    this.boardingCount,
    this.studentCount,
    this.isResuming = false,
  });

  final String title;
  final String? elapsedTime;
  final int? boardingCount;
  final int? studentCount;
  final VoidCallback onResume;
  final VoidCallback onEnd;
  final bool isResuming;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final details = <String>[
      if (elapsedTime != null) '운행 시작 후 $elapsedTime',
      if (boardingCount != null && studentCount != null)
        '탑승 $boardingCount/$studentCount명',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '진행 중인 운행',
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              details.join(' · '),
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isResuming ? null : onResume,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('운행 재개'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: isResuming
                    ? null
                    : () => _confirmEndTrip(context, onEnd),
                child: const Text('운행 종료'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmEndTrip(
    BuildContext context,
    VoidCallback onConfirm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('운행 종료'),
        content: const Text('기존 운행 화면으로 이동합니다. 운행 종료는 탑승·하차 확인 절차에서 진행됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirm();
  }
}

class NextTripCard extends StatelessWidget {
  const NextTripCard({
    super.key,
    required this.departureTime,
    required this.busName,
    required this.routeName,
    required this.onStart,
    this.isStarting = false,
  });

  final String departureTime;
  final String busName;
  final String routeName;
  final VoidCallback onStart;
  final bool isStarting;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_bus_rounded, color: colors.primary, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '다음 운행',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$departureTime 출발 · $busName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  routeName,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: isStarting ? null : onStart,
            child: const Text('운행 시작'),
          ),
        ],
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_bus_rounded, color: colors.primary, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '안전한 운행을 시작하세요',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '버스를 배정받으면 아래에 목록이 표시됩니다.',
                  style: TextStyle(
                    color: colors.onPrimaryContainer.withValues(alpha: 0.75),
                    fontSize: 13,
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

class AssignedBusCard extends StatelessWidget {
  const AssignedBusCard({
    super.key,
    required this.busName,
    required this.busNumber,
    required this.departureLabel,
    required this.routeName,
    required this.studentCount,
    required this.isActive,
    required this.onTap,
    this.isEnabled = true,
  });

  final String busName;
  final String busNumber;
  final String departureLabel;
  final String routeName;
  final int studentCount;
  final bool isActive;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isEnabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.directions_bus_rounded,
                          size: 30,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 7,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    busName,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  if (isActive) const StatusBadge('운행 중'),
                                ],
                              ),
                              Text(
                                busNumber,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time, size: 18),
                            const SizedBox(height: 3),
                            Text(
                              departureLabel,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final route = _InfoItem(
                          icon: Icons.route,
                          label: routeName,
                        );
                        final students = _InfoItem(
                          icon: Icons.people,
                          label: '탑승 예정 학생 $studentCount명',
                        );
                        if (constraints.maxWidth < 290) {
                          return Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [route, students],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: route),
                            const SizedBox(width: 12),
                            Expanded(child: students),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 7),
        Flexible(child: Text(label)),
      ],
    );
  }
}
