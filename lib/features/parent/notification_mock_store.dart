
import 'package:flutter/foundation.dart';

class NotificationMockStore {
  static final ValueNotifier<Set<int>> readIds =
  ValueNotifier<Set<int>>(<int>{});

  static final ValueNotifier<int> unreadCount =
  ValueNotifier<int>(0);

  // 기존 알림의 읽지 않은 개수
  static int _normalUnreadCount = 0;

  // 미하차 테스트 경고 상태
  static bool _hasTestAlert = false;
  static bool _testAlertRead = false;

  static void _updateUnreadCount() {
    unreadCount.value = _normalUnreadCount +
        (_hasTestAlert && !_testAlertRead ? 1 : 0);
  }

  static void updateNotifications(
      List<int> notificationIds,
      Set<int> initiallyReadIds,
      ) {
    final mergedReadIds = <int>{
      ...readIds.value,
      ...initiallyReadIds,
    };

    readIds.value = mergedReadIds;

    _normalUnreadCount = notificationIds
        .where((id) => !mergedReadIds.contains(id))
        .length;

    _updateUnreadCount();
  }

  static void markAsRead(int id) {
    if (readIds.value.contains(id)) return;

    readIds.value = {...readIds.value, id};

    if (_normalUnreadCount > 0) {
      _normalUnreadCount--;
    }

    _updateUnreadCount();
  }

  static bool isRead(int id, bool originalRead) {
    return originalRead || readIds.value.contains(id);
  }

  // 모든 일반 알림 및 미하차 테스트 경고 읽음 처리
  static void markAllAsRead(List<int> notificationIds) {
    readIds.value = {
      ...readIds.value,
      ...notificationIds,
    };

    _normalUnreadCount = 0;

    if (_hasTestAlert) {
      _testAlertRead = true;
    }

    _updateUnreadCount();
  }

  // 테스트 경고 발생
  static void addTestAlert() {
    if (_hasTestAlert) return;

    _hasTestAlert = true;
    _testAlertRead = false;

    _updateUnreadCount();
  }

  // 테스트 경고 읽음 처리
  static void readTestAlert() {
    if (!_hasTestAlert || _testAlertRead) return;

    _testAlertRead = true;

    _updateUnreadCount();
  }

  // 테스트 경고 초기화
  static void removeTestAlert() {
    _hasTestAlert = false;
    _testAlertRead = false;

    _updateUnreadCount();
  }

  static bool get isTestAlertRead => _testAlertRead;
}
