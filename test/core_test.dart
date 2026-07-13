// 코어 로직 단위 테스트: 포맷터·윈도우 버퍼·폴백 추론·프로필·알림.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hack_app/core/format.dart';
import 'package:hack_app/core/models.dart';
import 'package:hack_app/core/providers.dart';
import 'package:hack_app/core/services/inference_service.dart';
import 'package:hack_app/core/services/notification_service.dart';

SensorReading _reading({
  required DateTime time,
  double temperatureC = 25,
  double humidity = 50,
  double co2 = 500,
  double motion = 0,
}) =>
    SensorReading(
      time: time,
      temperatureC: temperatureC,
      humidity: humidity,
      co2: co2,
      motion: motion,
    );

void main() {
  group('format', () {
    test('formatTimeKo 는 오전/오후를 올바르게 표기한다', () {
      expect(formatTimeKo(DateTime(2026, 7, 13, 15, 24)), '오후 3:24');
      expect(formatTimeKo(DateTime(2026, 7, 13, 0, 5)), '오전 12:05');
      expect(formatTimeKo(DateTime(2026, 7, 13, 12, 0)), '오후 12:00');
    });

    test('formatKoreanDate 는 월/일/요일을 표기한다', () {
      expect(formatKoreanDate(DateTime(2026, 7, 13)), '7월 13일 월요일');
    });
  });

  group('WindowBuffer', () {
    test('최근 N개 샘플만 유지한다', () {
      final WindowBuffer buffer = WindowBuffer(size: 3);
      for (int i = 0; i < 5; i++) {
        buffer.add(_reading(
            time: DateTime(2026, 1, 1, 0, 0, i), temperatureC: 20 + i.toDouble()));
      }
      expect(buffer.window.length, 3);
      expect(buffer.window.first.temperatureC, 22);
      expect(buffer.isReady, isTrue);
    });
  });

  group('FallbackInferenceEngine', () {
    test('높은 움직임이면 탑승으로 판정한다', () {
      final FallbackInferenceEngine engine = FallbackInferenceEngine();
      final List<SensorReading> window = <SensorReading>[
        for (int i = 0; i < 10; i++)
          _reading(time: DateTime(2026, 1, 1, 0, 0, i), motion: 0.8),
      ];
      final InferenceResult result = engine.infer(window);
      expect(result.occupied, isTrue);
      expect(result.source, InferenceSource.fallback);
    });
  });

  group('providers', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer(
          overrides: [
            notificationServiceProvider
                .overrideWith((ref) => MockNotificationService()),
          ],
        ));
    tearDown(() => container.dispose());

    test('프로필 기본값은 로그인 없는 "사용자"다', () {
      final SpaceProfile profile = container.read(profileProvider);
      expect(profile.userName, '사용자');
      expect(profile.email, isEmpty);
      expect(profile.isVehicleMode, isTrue);
      expect(profile.manufacturer, '현대');
    });

    test('제조사 변경 시 해당 카탈로그의 첫 모델로 초기화된다', () {
      container.read(profileProvider.notifier).setManufacturer('기아');
      final SpaceProfile profile = container.read(profileProvider);
      expect(profile.manufacturer, '기아');
      expect(profile.modelName, kVehicleCatalog['기아']!.first);
    });

    test('알림 평가: 탑승 중 + 고온이면 열사병 critical 알림이 발생한다', () {
      final DateTime t = DateTime(2026, 7, 13, 12);
      container.read(alertsProvider.notifier).evaluate(
            reading: _reading(time: t, temperatureC: 45, humidity: 40, motion: 0.9),
            result: InferenceResult(
                time: t, probability: 0.9, source: InferenceSource.fallback),
            occupiedSince: t, // 탑승 중(경과 0 → 장시간 알림은 없음)
            settings: const SettingsState(),
          );
      final List<AlertEvent> alerts = container.read(alertsProvider);
      expect(alerts, hasLength(1));
      expect(alerts.first.severity, AlertSeverity.critical);
    });

    test('탑승 OFF면 고온이어도 알림이 없다', () {
      final DateTime t = DateTime(2026, 7, 13, 12);
      container.read(alertsProvider.notifier).evaluate(
            reading: _reading(time: t, temperatureC: 50, humidity: 40),
            result: InferenceResult(
                time: t, probability: 0.9, source: InferenceSource.fallback),
            occupiedSince: null, // 비어있음
            settings: const SettingsState(),
          );
      expect(container.read(alertsProvider), isEmpty);
    });

    test('CO2 임계값 초과 시 경고 알림이 발생한다', () {
      final DateTime t = DateTime(2026, 7, 13, 12);
      container.read(alertsProvider.notifier).evaluate(
            reading: _reading(time: t, temperatureC: 24, co2: 1800),
            result: InferenceResult(
                time: t, probability: 0.1, source: InferenceSource.fallback),
            occupiedSince: null,
            settings: const SettingsState(),
          );
      final List<AlertEvent> alerts = container.read(alertsProvider);
      expect(alerts, hasLength(1));
      expect(alerts.first.type, AlertType.highCo2);
      expect(alerts.first.severity, AlertSeverity.warning);
    });

    test('데이터 소스 전환/ESP 주소/MQTT 설정이 반영된다', () {
      final SettingsNotifier notifier =
          container.read(settingsProvider.notifier);
      notifier.setSensorSource(SensorDataSource.esp);
      notifier.setEspBaseUrl('http://10.0.2.2:8080');

      final SettingsState s1 = container.read(settingsProvider);
      expect(s1.sensorSource, SensorDataSource.esp);
      expect(s1.espBaseUrl, 'http://10.0.2.2:8080');

      notifier.setSensorSource(SensorDataSource.mqtt);
      notifier.setMqttHost('broker.example.com');
      notifier.setMqttPort(8883);
      notifier.setDeviceSerial('SAVEIN-TEST');

      final SettingsState s2 = container.read(settingsProvider);
      expect(s2.sensorSource, SensorDataSource.mqtt);
      expect(s2.mqttHost, 'broker.example.com');
      expect(s2.mqttPort, 8883);
      expect(s2.deviceSerial, 'SAVEIN-TEST');
    });
  });
}
