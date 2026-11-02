import 'package:flutter/material.dart';

Future<bool> showLogoutConfirmationDialog(BuildContext context) async {
  return await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '로그아웃',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  '로그아웃하시겠습니까?',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('로그아웃'),
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
