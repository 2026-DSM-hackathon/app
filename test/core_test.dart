// 코어 로직 단위 테스트: 포맷터·윈도우 버퍼·폴백 추론·프로필·알림.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hack_app/core/format.dart';
import 'package:hack_app/core/models.dart';
import 'package:hack_app/core/providers.dart';
import 'package:hack_app/core/services/inference_service.dart';

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
        buffer.add(SensorReading(
          time: DateTime(2026, 1, 1, 0, 0, i),
          temperatureC: 20 + i.toDouble(),
          motion: 0,
        ));
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
          SensorReading(
            time: DateTime(2026, 1, 1, 0, 0, i),
            temperatureC: 25,
            motion: 0.8,
          ),
      ];
      final InferenceResult result = engine.infer(window);
      expect(result.occupied, isTrue);
      expect(result.source, InferenceSource.fallback);
    });
  });

  group('providers', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
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

    test('알림 평가: 고온+탑승이면 critical 알림이 발생한다', () {
      final DateTime t = DateTime(2026, 7, 13, 12);
      container.read(alertsProvider.notifier).evaluate(
            reading:
                SensorReading(time: t, temperatureC: 45, motion: 0.9),
            result: InferenceResult(
                time: t, probability: 0.9, source: InferenceSource.fallback),
            occupiedSince: null,
            settings: const SettingsState(),
          );
      final List<AlertEvent> alerts = container.read(alertsProvider);
      expect(alerts, hasLength(1));
      expect(alerts.first.severity, AlertSeverity.critical);
      // tearDown 의 dispose 가 에스컬레이션 타이머를 취소해야 한다(초기화 오류 수정).
    });

    test('데이터 소스 전환/ESP 주소/BLE 목업 설정이 반영된다', () {
      final SettingsNotifier notifier =
          container.read(settingsProvider.notifier);
      notifier.setSensorSource(SensorDataSource.esp);
      notifier.setEspBaseUrl('http://10.0.2.2:8080');
      notifier.setUseMockBle(true);

      final SettingsState s = container.read(settingsProvider);
      expect(s.sensorSource, SensorDataSource.esp);
      expect(s.espBaseUrl, 'http://10.0.2.2:8080');
      expect(s.useMockBle, isTrue);
      expect(container.read(blePairingIsMockProvider), isTrue);
    });
  });
}
