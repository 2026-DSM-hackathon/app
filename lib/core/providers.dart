import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'services/esp_sensor_service.dart';
import 'services/inference_service.dart';
import 'services/mqtt_service.dart';
import 'services/notification_service.dart';
import 'services/sensor_service.dart';

// ---------------------------------------------------------------------------
// 서비스 프로바이더 — 데이터 소스는 설정에서 전환한다(목업 ↔ ESP 서버 ↔ MQTT)
// ---------------------------------------------------------------------------

/// MQTT 서비스: 데이터 소스가 MQTT 일 때만 브로커에 연결한다(아니면 null).
///
/// 브로커 host/port 또는 기기 시리얼이 바뀌면 프로바이더가 재생성되어 재연결한다.
final mqttServiceProvider = Provider<MqttSensorService?>((ref) {
  final SensorDataSource source =
      ref.watch(settingsProvider.select((s) => s.sensorSource));
  if (source != SensorDataSource.mqtt) return null;

  final String host = ref.watch(settingsProvider.select((s) => s.mqttHost));
  final int port = ref.watch(settingsProvider.select((s) => s.mqttPort));
  final String serial =
      ref.watch(settingsProvider.select((s) => s.deviceSerial));
  final bool requested = ref.watch(mqttConnectRequestedProvider);

  final MqttSensorService service =
      MqttSensorService(host: host, port: port, serial: serial);
  // 자동 연결 금지 — '등록하고 연결'(requested)을 눌렀을 때만 실제로 연결한다.
  // 부수효과(연결 시작)는 빌드 도중을 피해 다음 마이크로태스크로 미룬다.
  if (requested) {
    Future<void>.microtask(service.connect);
  }
  ref.onDispose(service.dispose);
  return service;
});

/// MQTT 링크 상태(브로커/POD). 데이터 소스가 MQTT 가 아니면 빈 스트림(대기).
final mqttLinkProvider = StreamProvider<MqttLink>((ref) {
  final MqttSensorService? s = ref.watch(mqttServiceProvider);
  if (s == null) return const Stream<MqttLink>.empty();
  return s.linkStream();
});

/// '직접 연결' 요청 여부. 등록·연결 버튼을 누르기 전에는 MQTT 에 연결하지 않는다.
/// 앱을 새로 켤 때마다 false 로 시작하므로, 매번 연결을 직접 눌러야 한다.
class MqttConnectRequestedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void request() => state = true;
  void reset() => state = false;
}

final mqttConnectRequestedProvider =
    NotifierProvider<MqttConnectRequestedNotifier, bool>(
        MqttConnectRequestedNotifier.new);

/// MQTT 연결 상태(연결 전 / 연결 중 / 연결됨). UI 표시·기능 게이트에 사용.
enum MqttStatus { idle, connecting, connected }

extension MqttStatusLabel on MqttStatus {
  String get label => switch (this) {
        MqttStatus.idle => 'MQTT 연결 전',
        MqttStatus.connecting => '연결 중…',
        MqttStatus.connected => '연결됨',
      };
}

final mqttStatusProvider = Provider<MqttStatus>((ref) {
  final bool sourceIsMqtt =
      ref.watch(settingsProvider.select((s) => s.sensorSource)) ==
          SensorDataSource.mqtt;
  final bool requested = ref.watch(mqttConnectRequestedProvider);
  if (!sourceIsMqtt || !requested) return MqttStatus.idle;
  final bool connected =
      ref.watch(mqttLinkProvider).value?.brokerConnected ?? false;
  return connected ? MqttStatus.connected : MqttStatus.connecting;
});

/// MQTT 연결됨 여부(연결 게이트). 미연결 시 대시보드 기능을 비활성화한다.
final mqttConnectedProvider = Provider<bool>((ref) {
  return ref.watch(mqttStatusProvider) == MqttStatus.connected;
});

/// 센서 소스: 설정의 데이터 소스에 따라 목업/ESP HTTP/MQTT 를 사용한다.
final sensorServiceProvider = Provider<SensorService>((ref) {
  final SensorDataSource source =
      ref.watch(settingsProvider.select((s) => s.sensorSource));

  switch (source) {
    case SensorDataSource.mock:
      final MockSensorService s = MockSensorService();
      ref.onDispose(s.dispose);
      return s;
    case SensorDataSource.esp:
      final String espUrl =
          ref.watch(settingsProvider.select((s) => s.espBaseUrl));
      final EspSensorService s = EspSensorService(baseUrl: espUrl);
      ref.onDispose(s.dispose);
      return s;
    case SensorDataSource.mqtt:
      // 수명은 mqttServiceProvider 가 소유하므로 여기서 dispose 하지 않는다.
      return ref.watch(mqttServiceProvider)!;
  }
});

final sensorStreamProvider = StreamProvider<SensorReading>((ref) {
  return ref.watch(sensorServiceProvider).readings();
});

final inferenceEngineProvider =
    Provider<InferenceEngine>((ref) => FallbackInferenceEngine());

final notificationServiceProvider =
    Provider<NotificationService>((ref) => MockNotificationService());

// ---------------------------------------------------------------------------
// 설정 (6.7)
// ---------------------------------------------------------------------------

class SettingsState {
  const SettingsState({
    this.tempThresholdC = 39,
    this.co2ThresholdPpm = 1500,
    this.elapsedThresholdSec = 120,
    this.probabilityThreshold = 0.5,
    this.emergencyContacts = const <EmergencyContact>[
      EmergencyContact(name: '보호자', phone: '010-1234-5678'),
    ],
    this.sensorSource = SensorDataSource.mqtt,
    this.espBaseUrl = 'http://192.168.0.10',
    this.mqttHost = 'broker.emqx.io',
    this.mqttPort = 1883,
    this.deviceSerial = 'SVN-EED364',
  });

  final double tempThresholdC;

  /// CO2 경고 임계값(ppm).
  final double co2ThresholdPpm;
  final int elapsedThresholdSec;
  final double probabilityThreshold;
  final List<EmergencyContact> emergencyContacts;

  /// 센서 데이터 소스(목업/ESP 서버/MQTT).
  final SensorDataSource sensorSource;

  /// ESP 보드 서버 베이스 URL (예: http://192.168.0.42).
  final String espBaseUrl;

  /// MQTT 브로커 호스트 (예: broker.emqx.io).
  final String mqttHost;

  /// MQTT 브로커 포트 (평문 1883 / TLS 8883).
  final int mqttPort;

  /// 하드웨어 기기 시리얼 넘버 — savein/{시리얼}/* 토픽으로 통신한다.
  final String deviceSerial;

  SettingsState copyWith({
    double? tempThresholdC,
    double? co2ThresholdPpm,
    int? elapsedThresholdSec,
    double? probabilityThreshold,
    List<EmergencyContact>? emergencyContacts,
    SensorDataSource? sensorSource,
    String? espBaseUrl,
    String? mqttHost,
    int? mqttPort,
    String? deviceSerial,
  }) =>
      SettingsState(
        tempThresholdC: tempThresholdC ?? this.tempThresholdC,
        co2ThresholdPpm: co2ThresholdPpm ?? this.co2ThresholdPpm,
        elapsedThresholdSec: elapsedThresholdSec ?? this.elapsedThresholdSec,
        probabilityThreshold: probabilityThreshold ?? this.probabilityThreshold,
        emergencyContacts: emergencyContacts ?? this.emergencyContacts,
        sensorSource: sensorSource ?? this.sensorSource,
        espBaseUrl: espBaseUrl ?? this.espBaseUrl,
        mqttHost: mqttHost ?? this.mqttHost,
        mqttPort: mqttPort ?? this.mqttPort,
        deviceSerial: deviceSerial ?? this.deviceSerial,
      );
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void setTempThreshold(double v) =>
      state = state.copyWith(tempThresholdC: v);
  void setCo2Threshold(double ppm) =>
      state = state.copyWith(co2ThresholdPpm: ppm);
  void setElapsedThreshold(int sec) =>
      state = state.copyWith(elapsedThresholdSec: sec);
  void setProbabilityThreshold(double v) =>
      state = state.copyWith(probabilityThreshold: v);

  void setSensorSource(SensorDataSource source) =>
      state = state.copyWith(sensorSource: source);
  void setEspBaseUrl(String url) => state = state.copyWith(espBaseUrl: url);
  void setMqttHost(String host) => state = state.copyWith(mqttHost: host);
  void setMqttPort(int port) => state = state.copyWith(mqttPort: port);
  void setDeviceSerial(String serial) =>
      state = state.copyWith(deviceSerial: serial);

  /// MQTT 소스 설정을 한 번에 적용(원자적 갱신 — 연속 상태 변경 캐스케이드 방지).
  void applyMqttConfig({
    required String serial,
    required String host,
    required int port,
  }) =>
      state = state.copyWith(
        deviceSerial: serial,
        mqttHost: host,
        mqttPort: port,
        sensorSource: SensorDataSource.mqtt,
      );

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
          id: 'SVN-EED364', // 시리얼 넘버 = savein/{id}/* 토픽 키
          name: 'SAVEIN Pod',
          battery: -1, // 배터리는 telemetry/status 로 갱신(현재 미확정)
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

    // 열사병 위험: 차주 하차 상태 + 고온.
    if (occupied && reading.temperatureC >= settings.tempThresholdC) {
      _fire(
        AlertType.highTemperature,
        AlertSeverity.critical,
        now,
        '열사병 위험 경고',
        '실내 ${reading.temperatureC.toStringAsFixed(1)}°C · 차주 하차 상태 — 즉시 확인하세요',
      );
    }

    // CO2 농도 경고(환기 부족). 매우 높고(≥2000) 차주 하차 상태면 위험으로 격상.
    if (reading.co2 >= settings.co2ThresholdPpm) {
      final bool severe = occupied && reading.co2 >= 2000;
      _fire(
        AlertType.highCo2,
        severe ? AlertSeverity.critical : AlertSeverity.warning,
        now,
        severe ? 'CO₂ 위험 농도' : 'CO₂ 농도 높음',
        '실내 CO₂ ${reading.co2.toStringAsFixed(0)}ppm — 환기가 필요해요',
      );
    }

    if (occupiedSince != null) {
      final Duration elapsed = now.difference(occupiedSince);
      if (elapsed.inSeconds >= settings.elapsedThresholdSec) {
        _fire(
          AlertType.prolongedOccupancy,
          AlertSeverity.warning,
          now,
          '장시간 방치 경고',
          '차주 하차 후 ${elapsed.inMinutes}분째 지속되고 있어요',
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

  /// POD(MQTT `event` 토픽)가 발행한 상태 전이 이벤트를 알림 목록에 편입한다.
  void ingestExternal(AlertEvent alert) {
    final DateTime? last = _lastFired[alert.type];
    if (last != null &&
        alert.time.difference(last) < const Duration(seconds: 20)) {
      return; // 동일 유형 쿨다운
    }
    _lastFired[alert.type] = alert.time;
    state = <AlertEvent>[alert, ...state];
    ref.read(notificationServiceProvider).showLocal(alert);
    if (alert.severity == AlertSeverity.critical) {
      _scheduleEscalation(alert);
    }
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
        '실내 51.0°C · 차주 하차 상태 — 즉시 확인하세요',
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
  final bool occupied; // 수동 토글: true = 차주 하차 상태(경과시간 측정 중)
  final DateTime? occupiedSince; // 6.9: 차주 하차 시각

  double get probability => inference?.probability ?? 0;
  double get temperatureC => latest?.temperatureC ?? 0;
  double get humidity => latest?.humidity ?? 0;
  double get co2 => latest?.co2 ?? 0;
  double get heatstroke => latest?.heatstrokeRisk ?? 0; // 0.0~1.0 열사병 확률

  /// 내부 사람 감지 — POD 재실(occ)을 직접 사용(즉시 반영). 실측값이 없으면
  /// 움직임 기반 추론으로 폴백한다.
  bool get detected => latest?.occupancy ?? (inference?.occupied ?? false);

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
  StreamSubscription<AlertEvent>? _eventSub;
  bool _disposed = false;

  @override
  MonitorState build() {
    ref.listen(sensorStreamProvider, (prev, next) {
      final SensorReading? reading = next.value;
      if (reading != null) _onReading(reading);
    });

    // MQTT POD 의 event/status 를 구독해 알림으로 편입한다(소스 전환 시 재바인딩).
    // fireImmediately 대신 마이크로태스크로 초기 바인딩해 빌드 중 부수효과를 피한다.
    ref.listen<MqttSensorService?>(
        mqttServiceProvider, (prev, next) => _bindMqtt(next));
    Future<void>.microtask(() {
      if (!_disposed) _bindMqtt(ref.read(mqttServiceProvider));
    });

    // 브로커 연결이 (재)수립되면 현재 차주 하차 여부를 cmd 로 즉시 발행해 POD 와
    // 동기화한다(retain 이라 마지막 상태가 브로커에 유지됨). 앱이 하차 여부의 발행자다.
    ref.listen<AsyncValue<MqttLink>>(mqttLinkProvider, (prev, next) {
      final bool was = prev?.value?.brokerConnected ?? false;
      final bool now = next.value?.brokerConnected ?? false;
      if (!was && now && !_disposed) {
        ref.read(mqttServiceProvider)?.publishOwnerAway(state.occupied);
      }
    });

    ref.onDispose(() {
      _disposed = true;
      _eventSub?.cancel();
    });
    return MonitorState.initial();
  }

  void _bindMqtt(MqttSensorService? service) {
    _eventSub?.cancel();
    _eventSub = null;
    if (service == null) return;
    // status=offline 이벤트도 서비스가 eventStream 으로 함께 발행한다.
    // 교차 프로바이더(alerts) 수정은 빌드 phase 경합을 피하려 마이크로태스크로 미룬다.
    _eventSub = service.eventStream().listen((AlertEvent e) {
      if (_disposed) return;
      Future<void>.microtask(() {
        if (!_disposed) ref.read(alertsProvider.notifier).ingestExternal(e);
      });
    });
  }

  /// 차주 하차 상태 수동 온/오프(대시보드 토글). 켤 때 경과시간 측정 시작(6.9).
  void setOccupied(bool value) {
    state = MonitorState(
      latest: state.latest,
      inference: state.inference,
      history: state.history,
      sensorHistory: state.sensorHistory,
      occupied: value,
      occupiedSince: value ? (state.occupiedSince ?? DateTime.now()) : null,
    );

    // §5.1 차주 하차 토글 → cmd 로 retain 발행(MQTT 소스일 때만).
    // 토글 ON(value=true) = 차주 하차 = owner_away=1. 상태를 그대로 away 로 보낸다.
    ref.read(mqttServiceProvider)?.publishOwnerAway(value);

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

    // 차주 하차 상태는 수동 토글 값을 유지한다.
    state = MonitorState(
      latest: r,
      inference: result,
      history: history,
      sensorHistory: sensorHistory,
      occupied: state.occupied,
      occupiedSince: state.occupiedSince,
    );

    // 알림 평가(교차 프로바이더 수정)는 빌드 phase 와의 경합을 피하려 마이크로태스크로 미룬다.
    final DateTime? occupiedSince = state.occupiedSince;
    Future<void>.microtask(() {
      if (_disposed) return;
      ref.read(alertsProvider.notifier).evaluate(
            reading: r,
            result: result,
            occupiedSince: occupiedSince,
            settings: settings,
          );
    });
  }
}

final monitorProvider =
    NotifierProvider<MonitorNotifier, MonitorState>(MonitorNotifier.new);
