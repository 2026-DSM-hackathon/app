import 'package:flutter/foundation.dart';

import '../models.dart';

/// 알림 채널 인터페이스(6.5). 실제 구현은 flutter_local_notifications.
abstract interface class NotificationService {
  /// 플러그인/타임존 초기화.
  Future<void> init();

  /// 알림 권한 요청(Android 13+/iOS). 허용 여부 반환.
  Future<bool> requestPermission();

  /// 로컬 알림 표시(치명 알림은 풀스크린 인텐트).
  Future<void> showLocal(AlertEvent alert);

  /// 에스컬레이션(비상연락처 통보 대체 — 강한 재알림).
  Future<void> escalate(AlertEvent alert);

  /// 앱을 종료해도 [delay] 뒤 OS가 띄우는 예약 알림(열사병 데모).
  Future<void> scheduleDelayedCritical({
    required String title,
    required String body,
    Duration delay,
  });
}

/// 목업 알림: 디버그 로그만 출력(테스트/미지원 플랫폼용).
class MockNotificationService implements NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showLocal(AlertEvent alert) async {
    debugPrint(
        '[LOCAL NOTI][${alert.severity.name}] ${alert.title} · ${alert.message}');
  }

  @override
  Future<void> escalate(AlertEvent alert) async {
    debugPrint('[ESCALATE] ${alert.title} → 비상연락처 통보(목업)');
  }

  @override
  Future<void> scheduleDelayedCritical({
    required String title,
    required String body,
    Duration delay = const Duration(seconds: 15),
  }) async {
    debugPrint('[SCHEDULE ${delay.inSeconds}s] $title · $body');
  }
}
