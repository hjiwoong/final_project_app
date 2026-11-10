import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/models/trip_exit_action.dart';

Future<TripExitAction?> showTripExitSheet(
  BuildContext context,
) => showModalBottomSheet<TripExitAction>(
  context: context,
  isScrollControlled: false,
  enableDrag: false,
  backgroundColor: Colors.transparent,
  builder: (context) => SafeArea(
    top: false,
    child: Container(
      margin: AppTheme.sheetMargin,
      decoration: AppTheme.sheetDecoration(context, radius: 20),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '운행 진행 중',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '운행을 취소하거나 현재 상태로 대기할 수 있습니다.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              foregroundColor: Theme.of(context).colorScheme.error,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(TripExitAction.cancel),
            child: const Row(
              children: [
                Icon(Icons.close_outlined),
                SizedBox(width: 10),
                Text('운행 취소'),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(TripExitAction.wait),
            child: const Row(
              children: [
                Icon(Icons.access_time_outlined),
                SizedBox(width: 10),
                Text('운행 대기'),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
