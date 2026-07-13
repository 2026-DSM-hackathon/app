import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'services/ble_pairing_service.dart';
import 'services/inference_service.dart';
import 'services/notification_service.dart';
import 'services/sensor_service.dart';

// ---------------------------------------------------------------------------
// 서비스 프로바이더 (모두 인터페이스 → 목업 구현. 실물로 교체 가능)
// ---------------------------------------------------------------------------

final sensorServiceProvider = Provider<SensorService>((ref) {
  final SensorService service = MockSensorService();
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

final blePairingServiceProvider =
    Provider<BlePairingService>((ref) => MockBlePairingService());

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
  });

  final double tempThresholdC;
  final int elapsedThresholdSec;
  final double probabilityThreshold;
  final List<EmergencyContact> emergencyContacts;

  SettingsState copyWith({
    double? tempThresholdC,
    int? elapsedThresholdSec,
    double? probabilityThreshold,
    List<EmergencyContact>? emergencyContacts,
  }) =>
      SettingsState(
        tempThresholdC: tempThresholdC ?? this.tempThresholdC,
        elapsedThresholdSec: elapsedThresholdSec ?? this.elapsedThresholdSec,
        probabilityThreshold: probabilityThreshold ?? this.probabilityThreshold,
        emergencyContacts: emergencyContacts ?? this.emergencyContacts,
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
// 차종/공간 프로필 (6.6)
// ---------------------------------------------------------------------------

class ProfileNotifier extends Notifier<SpaceProfile> {
  @override
  SpaceProfile build() => const SpaceProfile(
        userName: 'Emily Ashley',
        email: 'emiashley@gmail.com',
        spaceType: SpaceType.car,
        modelName: '현대 아이오닉 5',
      );

  void update(SpaceProfile profile) => state = profile;
  void setSpaceType(SpaceType t) => state = state.copyWith(spaceType: t);
  void setModelName(String name) => state = state.copyWith(modelName: name);
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
  int _seq = 0;

  @override
  List<AlertEvent> build() => const <AlertEvent>[];

  /// 모니터 스트림에서 호출되어 임계값 조건을 평가한다.
  void evaluate({
    required SensorReading reading,
    required InferenceResult result,
    required DateTime? occupiedSince,
    required SettingsState settings,
  }) {
    final DateTime now = reading.time;

    if (reading.temperatureC >= settings.tempThresholdC &&
        result.probability >= settings.probabilityThreshold) {
      _fire(
        AlertType.highTemperature,
        AlertSeverity.critical,
        now,
        '고온 경고',
        '실내 ${reading.temperatureC.toStringAsFixed(1)}°C · 탑승 감지됨',
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
    Timer(const Duration(seconds: 10), () {
      final AlertEvent current =
          state.firstWhere((a) => a.id == alert.id, orElse: () => alert);
      if (!current.acknowledged) {
        _update(alert.id, (a) => a.copyWith(escalated: true));
        ref.read(notificationServiceProvider).escalate(alert);
      }
    });
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
        '고온 경고 (데모)',
        '실내 51.0°C · 탑승 감지됨',
      );
}

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
    required this.occupied,
    required this.occupiedSince,
  });

  final SensorReading? latest;
  final InferenceResult? inference;
  final List<InferenceResult> history; // 최근 추론 이력(차트용)
  final bool occupied;
  final DateTime? occupiedSince; // 6.9: 탑승 시작 시각

  double get probability => inference?.probability ?? 0;
  double get temperatureC => latest?.temperatureC ?? 0;

  factory MonitorState.initial() => const MonitorState(
        latest: null,
        inference: null,
        history: <InferenceResult>[],
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

  void _onReading(SensorReading r) {
    _buffer.add(r);
    final InferenceResult result =
        ref.read(inferenceEngineProvider).infer(_buffer.window);
    final SettingsState settings = ref.read(settingsProvider);

    // 6.9: 자리 on/off 전이 감지 → 탑승 시작 시각 유지/초기화.
    final bool nowOccupied = result.probability >= settings.probabilityThreshold;
    final bool was = state.occupied;
    final DateTime? since =
        nowOccupied ? (was ? state.occupiedSince : r.time) : null;

    final List<InferenceResult> history = [...state.history, result];
    if (history.length > 40) {
      history.removeRange(0, history.length - 40);
    }

    state = MonitorState(
      latest: r,
      inference: result,
      history: history,
      occupied: nowOccupied,
      occupiedSince: since,
    );

    ref.read(alertsProvider.notifier).evaluate(
          reading: r,
          result: result,
          occupiedSince: since,
          settings: settings,
        );
  }
}

final monitorProvider =
    NotifierProvider<MonitorNotifier, MonitorState>(MonitorNotifier.new);
