import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';
import 'notification_service.dart';

/// flutter_local_notifications 기반 실제 로컬 알림(6.5).
///
/// - 알림은 기기 자체(로컬)에서 발송 → 서버 불필요.
/// - 치명(열사병) 알림은 fullScreenIntent 로 헤드업/전체화면 팝업.
/// - [scheduleDelayedCritical] 은 OS AlarmManager 예약이라 **앱을 종료해도** 도착.
class LocalNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'heatstroke_alerts';
  static const String _channelName = '열사병·탑승 경보';
  static const String _channelDesc = '탑승 감지 및 고온(열사병) 경보 알림';

  @override
  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (_) {
      // 실패 시 UTC 유지.
    }

    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
    ));
  }

  @override
  Future<bool> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final bool granted =
          await android.requestNotificationsPermission() ?? false;
      // 앱 종료 후 예약 알림(정확 알람) 및 전체화면 권한도 요청.
      await android.requestExactAlarmsPermission();
      await android.requestFullScreenIntentPermission();
      return granted;
    }
    final IOSFlutterLocalNotificationsPlugin? ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  AndroidNotificationDetails _android({required bool fullScreen}) =>
      AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: fullScreen,
        ticker: '경보',
      );

  NotificationDetails _details({required bool fullScreen}) => NotificationDetails(
        android: _android(fullScreen: fullScreen),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
        ),
      );

  @override
  Future<void> showLocal(AlertEvent alert) async {
    final bool critical = alert.severity == AlertSeverity.critical;
    await _plugin.show(
      id: alert.id.hashCode,
      title: alert.title,
      body: alert.message,
      notificationDetails: _details(fullScreen: critical),
    );
  }

  @override
  Future<void> escalate(AlertEvent alert) async {
    await _plugin.show(
      id: 'esc_${alert.id}'.hashCode,
      title: '⚠️ ${alert.title} (에스컬레이션)',
      body: '${alert.message} · 비상연락처 확인이 필요합니다',
      notificationDetails: _details(fullScreen: true),
    );
  }

  @override
  Future<void> scheduleDelayedCritical({
    required String title,
    required String body,
    Duration delay = const Duration(seconds: 15),
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: 99001,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
        notificationDetails: _details(fullScreen: true),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      // 정확 알람 권한이 없으면 근사 예약으로 폴백.
      debugPrint('[SCHEDULE] exact 실패, inexact 폴백: $e');
      await _plugin.zonedSchedule(
        id: 99001,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
        notificationDetails: _details(fullScreen: true),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
