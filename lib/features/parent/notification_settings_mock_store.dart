
import 'package:flutter/foundation.dart';

// 학부모 알림 설정 (Mock 데이터)
class NotificationSettingsMockStore {
  // 승차 및 하차 알림
  static final ValueNotifier<bool> boardingEnabled =
  ValueNotifier<bool>(true);

  // 급정거, 과속, 경로 이탈 알림
  static final ValueNotifier<bool> safetyEnabled =
  ValueNotifier<bool>(true);

  // 미하차 의심 경고는 필수 알림이므로 항상 활성화
  static const bool leftBehindAlertEnabled = true;

  // 알림 설정 저장
  static void save({
    required bool boarding,
    required bool safety,
  }) {
    boardingEnabled.value = boarding;
    safetyEnabled.value = safety;
  }
}
