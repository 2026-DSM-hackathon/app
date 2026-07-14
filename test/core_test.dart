// 코어 로직 단위 테스트: 포맷터·윈도우 버퍼·폴백 추론·프로필·알림.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hack_app/core/format.dart';
import 'package:hack_app/core/models.dart';
import 'package:hack_app/core/providers.dart';
import 'package:hack_app/core/services/inference_service.dart';
import 'package:hack_app/core/services/mqtt_service.dart';
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

  group('MQTT telemetry 파싱(§4.1)', () {
    final DateTime t = DateTime(2026, 7, 13, 12);

    test('실제 스키마 키(t/rh/occ/dist/lv)를 올바르게 매핑한다', () {
      final SensorReading r = MqttSensorService.parseTelemetry(<String, dynamic>{
        'ts': 1752390000,
        't': 36.42,
        'rh': 58.30,
        'hi': 45.10,
        'dist': 812,
        'occ': 1,
        'lv': 3,
        'batt': 78,
      }, now: t);
      expect(r.temperatureC, 36.42); // t → 온도
      expect(r.humidity, 58.30); // rh → 습도
      expect(r.occupancy, isTrue); // occ=1 → 사람 감지됨
      expect(r.distanceMm, 812); // dist(mm)
      expect(r.heatstrokeRisk, closeTo(0.75, 1e-9)); // lv 3/4 → 열사병 확률
      expect(r.co2, 0); // §4.1 에 co2 필드 없음 → 0(더미값 아님)
    });

    test('occ=0 / dist=-1(측정 실패) 처리', () {
      final SensorReading r = MqttSensorService.parseTelemetry(
          <String, dynamic>{'t': 25, 'rh': 40, 'occ': 0, 'dist': -1}, now: t);
      expect(r.occupancy, isFalse);
      expect(r.distanceMm, isNull); // -1 → null
      expect(r.motion, 0);
    });

    test('펌웨어가 co2 필드를 추가하면 그대로 수신한다', () {
      final SensorReading r = MqttSensorService.parseTelemetry(
          <String, dynamic>{'t': 30, 'rh': 50, 'occ': 1, 'co2': 1350}, now: t);
      expect(r.co2, 1350);
    });

    test('실제 기기 페이로드(cnt/hint/p 포함)를 그대로 처리한다', () {
      // SVN-EED364 실측: co2 수신, p=-1(AI 미산출)이라 lv(=0)로 폴백.
      final SensorReading r = MqttSensorService.parseTelemetry(<String, dynamic>{
        'ts': 1784023999, 't': 24.13, 'rh': 52.30, 'hi': 23.97, 'dist': 1049,
        'co2': 3396, 'cnt': 0, 'occ': 0, 'hint': 0, 'p': -1, 'lv': 0,
        'mode': 0, 'exp': 0, 'batt': 255, 'seq': 39, 'fw': '0.1', 'flags': 36,
      }, now: t);
      expect(r.temperatureC, 24.13);
      expect(r.humidity, 52.30);
      expect(r.co2, 3396);
      expect(r.occupancy, isFalse); // occ=0
      expect(r.distanceMm, 1049);
      expect(r.heatstrokeRisk, 0); // p=-1 → lv 0/4 폴백 → 0
    });

    test('p(AI 열사병확률)가 0 이상이면 lv 대신 p 를 쓴다', () {
      final SensorReading hi = MqttSensorService.parseTelemetry(
          <String, dynamic>{'t': 40, 'occ': 1, 'p': 0.82, 'lv': 1}, now: t);
      expect(hi.heatstrokeRisk, closeTo(0.82, 1e-9)); // p 우선

      final SensorReading unset = MqttSensorService.parseTelemetry(
          <String, dynamic>{'t': 40, 'occ': 1, 'p': -1, 'lv': 2}, now: t);
      expect(unset.heatstrokeRisk, closeTo(0.5, 1e-9)); // p<0 → lv 2/4 폴백
    });
  });

  group('cmd 발행 payload(§5.1 owner_away)', () {
    test('차주 하차 ON → {type:config, owner_away:1}', () {
      expect(MqttSensorService.ownerAwayCommand(true),
          <String, dynamic>{'type': 'config', 'owner_away': 1});
    });
    test('차주 하차 OFF → {type:config, owner_away:0}', () {
      expect(MqttSensorService.ownerAwayCommand(false),
          <String, dynamic>{'type': 'config', 'owner_away': 0});
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
