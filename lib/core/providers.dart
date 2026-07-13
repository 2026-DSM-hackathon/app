import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'services/ble_pairing_service.dart';
import 'services/esp_sensor_service.dart';
import 'services/flutter_blue_pairing_service.dart';
import 'services/inference_service.dart';
import 'services/notification_service.dart';
import 'services/sensor_service.dart';

// ---------------------------------------------------------------------------
// 서비스 프로바이더 — 데이터 소스는 설정에서 전환한다(목업 ↔ ESP 서버 ↔ BLE)
// ---------------------------------------------------------------------------

/// 센서 소스: 설정의 데이터 소스에 따라 목업/ESP HTTP 폴링을 사용한다.
final sensorServiceProvider = Provider<SensorService>((ref) {
  final SensorDataSource source =
      ref.watch(settingsProvider.select((s) => s.sensorSource));
  final String espUrl =
      ref.watch(settingsProvider.select((s) => s.espBaseUrl));

  final SensorService service = switch (source) {
    SensorDataSource.mock => MockSensorService(),
    SensorDataSource.esp => EspSensorService(baseUrl: espUrl),
  };
  ref.onDispose(service.dispose);
  return service;
});

final sensorStreamProvider = StreamProvider<SensorReading>((ref) {
  return ref.watch(sensorServiceProvider).readings();
});

final inferenceEngineProvider =
    Provider<InferenceEngine>((ref) => FallbackInferenceEngine());

final notificationServiceProvider =
    Provider<NotificationService>((ref) => MockNotificationService());

/// 이 플랫폼/설정에서 BLE 페어링이 목업으로 동작하는지.
final blePairingIsMockProvider = Provider<bool>((ref) {
  final bool forceMock =
      ref.watch(settingsProvider.select((s) => s.useMockBle));
  final bool supported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  return forceMock || !supported;
});

/// BLE 페어링: Android/iOS 에서는 실제(flutter_blue_plus), 그 외/강제 시 목업.
final blePairingServiceProvider = Provider<BlePairingService>((ref) {
  return ref.watch(blePairingIsMockProvider)
      ? MockBlePairingService()
      : FlutterBluePairingService();
});

// ---------------------------------------------------------------------------
// 설정 (6.7)
// ---------------------------------------------------------------------------

class SettingsState {
  const SettingsState({
    this.tempThresholdC = 39,
    this.elapsedThresholdSec = 120,
    this.probabilityThreshold = 0.5,
    this.emergencyContacts = const <EmergencyContact>[
      EmergencyContact(name: '보호자', phone: '010-1234-5678'),
    ],
    this.sensorSource = SensorDataSource.mock,
    this.espBaseUrl = 'http://192.168.0.10',
    this.useMockBle = false,
  });

  final double tempThresholdC;
  final int elapsedThresholdSec;
  final double probabilityThreshold;
  final List<EmergencyContact> emergencyContacts;

  /// 센서 데이터 소스(목업/ESP 서버).
  final SensorDataSource sensorSource;

  /// ESP 보드 서버 베이스 URL (예: http://192.168.0.42).
  final String espBaseUrl;

  /// BLE 스캔을 목업으로 강제(에뮬레이터/BLE 미지원 환경용).
  final bool useMockBle;

  SettingsState copyWith({
    double? tempThresholdC,
    int? elapsedThresholdSec,
    double? probabilityThreshold,
    List<EmergencyContact>? emergencyContacts,
    SensorDataSource? sensorSource,
    String? espBaseUrl,
    bool? useMockBle,
  }) =>
      SettingsState(
        tempThresholdC: tempThresholdC ?? this.tempThresholdC,
        elapsedThresholdSec: elapsedThresholdSec ?? this.elapsedThresholdSec,
        probabilityThreshold: probabilityThreshold ?? this.probabilityThreshold,
        emergencyContacts: emergencyContacts ?? this.emergencyContacts,
        sensorSource: sensorSource ?? this.sensorSource,
        espBaseUrl: espBaseUrl ?? this.espBaseUrl,
        useMockBle: useMockBle ?? this.useMockBle,
      );
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void setTempThreshold(double v) =>
      state = state.copyWith(tempThresholdC: v);
  void setElapsedThreshold(int sec) =>
      state = state.copyWith(elapsedThresholdSec: sec);
  void setProbabilityThreshold(double v) =>
      state = state.copyWith(probabilityThreshold: v);

  void setSensorSource(SensorDataSource source) =>
      state = state.copyWith(sensorSource: source);
  void setEspBaseUrl(String url) => state = state.copyWith(espBaseUrl: url);
  void setUseMockBle(bool v) => state = state.copyWith(useMockBle: v);

  void addContact(EmergencyContact c) => state =
      state.copyWith(emergencyContacts: [...state.emergencyContacts, c]);
  void removeContact(int index) {
    final list = [...state.emergencyContacts]..removeAt(index);
    state = state.copyWith(emergencyContacts: list);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

// ---------------------------------------------------------------------------
// 차종/공간 프로필 (6.6) — 로그인 없음: 기본 사용자명 '사용자'
// ---------------------------------------------------------------------------

class ProfileNotifier extends Notifier<SpaceProfile> {
  @override
  SpaceProfile build() => const SpaceProfile(
        userName: '사용자',
        email: '', // 로그인 미사용
        spaceType: SpaceType.car,
        manufacturer: '현대',
        modelName: '아이오닉 5',
      );

  void update(SpaceProfile profile) => state = profile;
  void setUserName(String name) => state = state.copyWith(userName: name);
  void setSpaceType(SpaceType t) => state = state.copyWith(spaceType: t);
  void setModelName(String name) => state = state.copyWith(modelName: name);

  /// 제조사 변경. 카탈로그 제조사면 해당 첫 모델로 초기화한다.
  void setManufacturer(String manufacturer) {
    final List<String>? models = kVehicleCatalog[manufacturer];
    state = state.copyWith(
      manufacturer: manufacturer,
      modelName: models != null && models.isNotEmpty
          ? models.first
          : state.modelName,
    );
  }
}

final profileProvider =
    NotifierProvider<ProfileNotifier, SpaceProfile>(ProfileNotifier.new);

// ---------------------------------------------------------------------------
// 페어링된 기기 (6.2 / 6.7)
// ---------------------------------------------------------------------------

class DevicesNotifier extends Notifier<List<DeviceInfo>> {
  @override
  List<DeviceInfo> build() => const <DeviceInfo>[
        DeviceInfo(
          id: 'S-001',
          name: 'SeatGuard Radar A1',
          battery: 88,
          connected: true,
          sensorType: SensorType.radar,
        ),
      ];

  void add(DeviceInfo d) {
    if (state.any((e) => e.id == d.id)) return;
    state = [...state, d];
  }

  void remove(String id) => state = [
        for (final d in state)
          if (d.id != id) d,
      ];
}

final devicesProvider =
    NotifierProvider<DevicesNotifier, List<DeviceInfo>>(DevicesNotifier.new);

// ---------------------------------------------------------------------------
// 알림 (6.5): 조건 평가 → 발생 → ACK / 에스컬레이션
// ---------------------------------------------------------------------------

class AlertsNotifier extends Notifier<List<AlertEvent>> {
  final Map<AlertType, DateTime> _lastFired = <AlertType, DateTime>{};
  final Set<Timer> _timers = <Timer>{};
  bool _disposed = false;
  int _seq = 0;

  @override
  List<AlertEvent> build() {
    // 초기화 오류 방지: 프로바이더가 폐기되면(핫 리스타트 등) 진행 중인
    // 에스컬레이션 타이머를 모두 취소해, 폐기된 notifier 의 state 접근으로
    // "Uninitialized/disposed" 오류가 나지 않게 한다.
    ref.onDispose(() {
      _disposed = true;
      for (final Timer t in _timers) {
        t.cancel();
      }
      _timers.clear();
    });
    return const <AlertEvent>[];
  }

  /// 모니터 스트림에서 호출되어 임계값 조건을 평가한다.
  void evaluate({
    required SensorReading reading,
    required InferenceResult result,
    required DateTime? occupiedSince,
    required SettingsState settings,
  }) {
    final DateTime now = reading.time;
    final bool occupied = occupiedSince != null;

    // 열사병 위험: 탑승 중 + 고온.
    if (occupied && reading.temperatureC >= settings.tempThresholdC) {
      _fire(
        AlertType.highTemperature,
        AlertSeverity.critical,
        now,
        '열사병 위험 경고',
        '실내 ${reading.temperatureC.toStringAsFixed(1)}°C · 탑승 중 — 즉시 확인하세요',
      );
    }

    if (occupiedSince != null) {
      final Duration elapsed = now.difference(occupiedSince);
      if (elapsed.inSeconds >= settings.elapsedThresholdSec) {
        _fire(
          AlertType.prolongedOccupancy,
          AlertSeverity.warning,
          now,
          '장시간 탑승',
          '${elapsed.inMinutes}분째 탑승 상태가 지속되고 있어요',
        );
      }
    }
  }

  void _fire(
    AlertType type,
    AlertSeverity sev,
    DateTime time,
    String title,
    String message,
  ) {
    final DateTime? last = _lastFired[type];
    if (last != null && time.difference(last) < const Duration(seconds: 20)) {
      return; // 쿨다운
    }
    _lastFired[type] = time;

    final AlertEvent alert = AlertEvent(
      id: 'A${_seq++}',
      type: type,
      severity: sev,
      time: time,
      title: title,
      message: message,
    );
    state = [alert, ...state];
    ref.read(notificationServiceProvider).showLocal(alert);
    if (sev == AlertSeverity.critical) {
      _scheduleEscalation(alert);
    }
  }

  /// 미확인 상태로 10초 경과 시 에스컬레이션.
  void _scheduleEscalation(AlertEvent alert) {
    late final Timer timer;
    timer = Timer(const Duration(seconds: 10), () {
      _timers.remove(timer);
      if (_disposed) return; // 폐기 후 state 접근 금지
      final AlertEvent current =
          state.firstWhere((a) => a.id == alert.id, orElse: () => alert);
      if (!current.acknowledged) {
        _update(alert.id, (a) => a.copyWith(escalated: true));
        ref.read(notificationServiceProvider).escalate(alert);
      }
    });
    _timers.add(timer);
  }

  void acknowledge(String id) =>
      _update(id, (a) => a.copyWith(acknowledged: true));

  void clearAll() => state = const <AlertEvent>[];

  void _update(String id, AlertEvent Function(AlertEvent) f) {
    state = [
      for (final a in state)
        if (a.id == id) f(a) else a,
    ];
  }

  /// 데모용 수동 트리거(풀스크린 경보 확인용).
  void triggerDemoCritical() => _fire(
        AlertType.highTemperature,
        AlertSeverity.critical,
        DateTime.now(),
        '열사병 위험 경고 (데모)',
        '실내 51.0°C · 탑승 중 — 즉시 확인하세요',
      );
}

/// 알림 권한 허용 여부(설정 토글 표시용).
class NotificationEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final notificationEnabledProvider =
    NotifierProvider<NotificationEnabledNotifier, bool>(
        NotificationEnabledNotifier.new);

final alertsProvider =
    NotifierProvider<AlertsNotifier, List<AlertEvent>>(AlertsNotifier.new);

final unacknowledgedCountProvider = Provider<int>((ref) {
  return ref.watch(alertsProvider).where((a) => !a.acknowledged).length;
});

// ---------------------------------------------------------------------------
// 모니터 (6.3 / 6.8 / 6.9): 센서 → 윈도우 버퍼 → 추론 → 상태/경과시간 + 알림
// ---------------------------------------------------------------------------

class MonitorState {
  const MonitorState({
    required this.latest,
    required this.inference,
    required this.history,
    required this.sensorHistory,
    required this.occupied,
    required this.occupiedSince,
  });

  final SensorReading? latest;
  final InferenceResult? inference;
  final List<InferenceResult> history; // 최근 추론 이력
  final List<SensorReading> sensorHistory; // 온·습도 추이 차트용
  final bool occupied; // 수동 토글로 설정하는 탑승 상태
  final DateTime? occupiedSince; // 6.9: 탑승 시작 시각

  double get probability => inference?.probability ?? 0;
  double get temperatureC => latest?.temperatureC ?? 0;
  double get humidity => latest?.humidity ?? 0;

  factory MonitorState.initial() => const MonitorState(
        latest: null,
        inference: null,
        history: <InferenceResult>[],
        sensorHistory: <SensorReading>[],
        occupied: false,
        occupiedSince: null,
      );
}

class MonitorNotifier extends Notifier<MonitorState> {
  final WindowBuffer _buffer = WindowBuffer(size: 15);

  @override
  MonitorState build() {
    ref.listen(sensorStreamProvider, (prev, next) {
      final SensorReading? reading = next.value;
      if (reading != null) _onReading(reading);
    });
    return MonitorState.initial();
  }

  /// 탑승 상태 수동 온/오프(대시보드 토글). 켤 때 경과시간 측정 시작(6.9).
  void setOccupied(bool value) {
    state = MonitorState(
      latest: state.latest,
      inference: state.inference,
      history: state.history,
      sensorHistory: state.sensorHistory,
      occupied: value,
      occupiedSince: value ? (state.occupiedSince ?? DateTime.now()) : null,
    );

    final SensorReading? r = state.latest;
    if (r != null) {
      ref.read(alertsProvider.notifier).evaluate(
            reading: r,
            result: state.inference ??
                InferenceResult(
                    time: r.time,
                    probability: 0,
                    source: InferenceSource.fallback),
            occupiedSince: state.occupiedSince,
            settings: ref.read(settingsProvider),
          );
    }
  }

  void _onReading(SensorReading r) {
    _buffer.add(r);
    final InferenceResult result =
        ref.read(inferenceEngineProvider).infer(_buffer.window);
    final SettingsState settings = ref.read(settingsProvider);

    final List<InferenceResult> history = [...state.history, result];
    if (history.length > 40) {
      history.removeRange(0, history.length - 40);
    }
    final List<SensorReading> sensorHistory = [...state.sensorHistory, r];
    if (sensorHistory.length > 40) {
      sensorHistory.removeRange(0, sensorHistory.length - 40);
    }

    // 탑승 상태는 수동 토글 값을 유지한다.
    state = MonitorState(
      latest: r,
      inference: result,
      history: history,
      sensorHistory: sensorHistory,
      occupied: state.occupied,
      occupiedSince: state.occupiedSince,
    );

    ref.read(alertsProvider.notifier).evaluate(
          reading: r,
          result: result,
          occupiedSince: state.occupiedSince,
          settings: settings,
        );
  }
}

final monitorProvider =
    NotifierProvider<MonitorNotifier, MonitorState>(MonitorNotifier.new);
