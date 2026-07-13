import 'package:flutter/foundation.dart';

import '../models.dart';

/// 알림 채널 인터페이스(6.5). 실제 구현은 flutter_local_notifications + FCM.
abstract interface class NotificationService {
  /// 로컬 알림 표시(풀스크린 인텐트 포함 가정).
  Future<void> showLocal(AlertEvent alert);

  /// 에스컬레이션(예: 비상연락처 통보).
  Future<void> escalate(AlertEvent alert);
}

/// 목업 알림: 디버그 로그만 출력한다.
///
/// TODO(real): flutter_local_notifications 로 fullScreenIntent 채널을 구성하고,
/// FCM data 메시지 수신 시 로컬 알림으로 승격. escalate 는 비상연락처 SMS/자동전화.
class MockNotificationService implements NotificationService {
  @override
  Future<void> showLocal(AlertEvent alert) async {
    debugPrint(
        '[LOCAL NOTI][${alert.severity.name}] ${alert.title} · ${alert.message}');
  }

  @override
  Future<void> escalate(AlertEvent alert) async {
    debugPrint('[ESCALATE] ${alert.title} → 비상연락처 통보(목업)');
  }
}
