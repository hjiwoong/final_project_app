import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/models/trip_exit_action.dart';

Future<TripExitAction?> showTripExitSheet(BuildContext context) =>
    showModalBottomSheet<TripExitAction>(
      context: context,
      isScrollControlled: false,
      enableDrag: false,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '운행 진행 중',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '운행을 취소하거나 현재 상태로 대기할 수 있습니다.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 58,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                  ),
                  onPressed: () =>
                      Navigator.of(context).pop(TripExitAction.cancel),
                  child: const Text('운행 취소'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 58,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(TripExitAction.wait),
                  child: const Text('운행 대기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
