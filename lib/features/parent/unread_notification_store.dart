import 'package:flutter/foundation.dart';

/// 서버(GET /me/notifications 의 unread_count)에서 받은 읽지 않은 알림 개수.
/// 하단 탭 배지와 알림 목록이 같은 값을 공유한다.
class UnreadNotificationStore {
  UnreadNotificationStore._();

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static void setCount(int count) {
    unreadCount.value = count < 0 ? 0 : count;
  }

  /// 알림 하나를 읽었을 때
  static void decrement() {
    if (unreadCount.value > 0) unreadCount.value--;
  }

  /// 모두 읽음 처리 / 로그아웃 시
  static void clear() {
    unreadCount.value = 0;
  }
}
