
import 'package:flutter/foundation.dart';

import 'notification_mock_store.dart';

class AlertMockStore {
  static final ValueNotifier<bool> hasAlert =
  ValueNotifier<bool>(false);

  static void triggerAlert() {
    if (hasAlert.value) return;

    NotificationMockStore.addTestAlert();
    hasAlert.value = true;
  }

  static void resetAlert() {
    NotificationMockStore.removeTestAlert();
    hasAlert.value = false;
  }
}
