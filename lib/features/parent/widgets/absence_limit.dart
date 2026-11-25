import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../data/api/api_repository.dart';

/// 한 달 결석 한도 (서버 MONTHLY_ABSENCE_LIMIT, 기본 4번)
class AbsenceLimit {
  const AbsenceLimit({
    required this.limit,
    required this.used,
    required this.canRequest,
    this.message,
  });

  final int limit;
  final int used;
  final bool canRequest;
  final String? message;

  int get remaining => (limit - used).clamp(0, limit);

  factory AbsenceLimit.fromJson(Map<String, dynamic> json) => AbsenceLimit(
    limit: (json['limit'] as num?)?.toInt() ?? 4,
    used: (json['used'] as num?)?.toInt() ?? 0,
    canRequest: json['can_request'] != false,
    message: json['message'] as String?,
  );
}

/// 한도 조회. 실패하면 null (서버가 신청할 때 다시 막으므로 앱은 그대로 진행)
Future<AbsenceLimit?> fetchAbsenceLimit(int studentId, DateTime date) async {
  try {
    return AbsenceLimit.fromJson(
      await ApiRepository.instance.getAbsenceLimit(studentId, date),
    );
  } catch (error) {
    debugPrint('결석 한도 조회 실패: $error');
    return null;
  }
}

/// 서버가 한도 초과로 거절한 응답인지 (409 + 안내 문구)
String? absenceLimitErrorMessage(Object error) {
  if (error is! DioException || error.response?.statusCode != 409) return null;
  final data = error.response?.data;
  final detail = data is Map ? data['detail'] : null;
  if (detail is String && detail.contains('더 이상 결석할 수 없어요')) return detail;
  return null;
}

/// '이번 달 결석 불가' 안내 창
Future<void> showAbsenceLimitDialog(
  BuildContext context, {
  required DateTime date,
  String? message,
  int limit = 4,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    icon: const Icon(Icons.event_busy_rounded),
    title: Text('${date.month}월에는 더 결석할 수 없어요'),
    content: Text(
      message ??
          '${date.month}월에는 이미 결석을 $limit번 신청해서 더 이상 결석할 수 없어요. '
              '꼭 결석해야 하면 기관에 연락해 주세요.',
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('확인'),
      ),
    ],
  ),
);

/// 결석으로 바꾸기 전에 확인: 신청할 수 있으면 한도 정보(또는 조회 실패 시 null)와 true,
/// 이번 달 한도를 다 썼으면 안내 창을 띄우고 false
Future<(bool, AbsenceLimit?)> ensureAbsenceAllowed(
  BuildContext context, {
  required int studentId,
  required DateTime date,
}) async {
  final limit = await fetchAbsenceLimit(studentId, date);
  if (limit != null && !limit.canRequest) {
    if (context.mounted) {
      await showAbsenceLimitDialog(
        context,
        date: date,
        message: limit.message,
        limit: limit.limit,
      );
    }
    return (false, limit);
  }
  return (true, limit);
}
