import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../models.dart';
import 'sensor_service.dart';

/// MQTT 링크 상태 스냅샷: 브로커 연결 여부 + POD 온라인 여부.
@immutable
class MqttLink {
  const MqttLink({
    required this.brokerConnected,
    required this.pod,
    this.error,
  });

  const MqttLink.connecting()
      : brokerConnected = false,
        pod = PodConnection.unknown,
        error = null;

  final bool brokerConnected;
  final PodConnection pod;
  final String? error;

  MqttLink copyWith({
    bool? brokerConnected,
    PodConnection? pod,
    String? error,
    bool clearError = false,
  }) =>
      MqttLink(
        brokerConnected: brokerConnected ?? this.brokerConnected,
        pod: pod ?? this.pod,
        error: clearError ? null : (error ?? this.error),
      );
}

/// SD 백필(sync) 진행 상태.
@immutable
class SyncProgress {
  const SyncProgress({
    required this.received,
    required this.total,
    required this.done,
  });

  final int received;
  final int total;
  final bool done;
}

/// savein/{serial}/* 토픽으로 하드웨어 POD 와 통신하는 MQTT 서비스.
///
/// 토픽 맵 ({ID} = 기기 시리얼):
///   savein/{ID}/telemetry  POD→APP  QoS0 retain  20초 주기 상태 JSON (구독 즉시 마지막값)
///   savein/{ID}/event      POD→APP  QoS1         상태 전이 이벤트 JSON
///   savein/{ID}/status     POD→APP  QoS1 retain  online/offline (LWT — 비정상 단절 시 브로커 발행)
///   savein/{ID}/sync       POD→APP  QoS1         SD 백필 응답 (info/data/end)
///   savein/{ID}/cmd        APP→POD  QoS1         명령 JSON(§5). 차주 토글은 retain 발행(§5.1)
///
/// TODO(fw): 아래 JSON 스키마는 임시 가안이다(§5·§5.1 미확정). 펌웨어 확정 시
///  필드명만 맞추면 되도록 방어적으로 파싱한다(여러 키 이름 허용).
///   telemetry → {"tempC":27.5,"humidity":55,"co2":780,"motion":0.42,"heatstroke":0.3}
///   event     → {"type":"high_co2","severity":"warning","message":"..."}
///   status    → "online" / "offline" (평문) 또는 {"status":"online"}
///   sync      → {"phase":"info","count":120} / {"phase":"data","samples":[...]} / {"phase":"end"}
///   cmd       → {"cmd":"owner_aboard","value":true} / {"cmd":"sync","since":...}
class MqttSensorService implements SensorService {
  MqttSensorService({
    required this.host,
    required this.port,
    required this.serial,
    this.username,
    this.password,
  });

  final String host;
  final int port;
  final String serial;
  final String? username;
  final String? password;

  MqttServerClient? _client;
  Timer? _retry;
  bool _disposed = false;
  int _evtSeq = 0;
  int _syncReceived = 0;
  int _syncTotal = 0;

  final StreamController<SensorReading> _telemetry =
      StreamController<SensorReading>.broadcast();
  final StreamController<AlertEvent> _events =
      StreamController<AlertEvent>.broadcast();
  final StreamController<MqttLink> _links =
      StreamController<MqttLink>.broadcast();
  final StreamController<SyncProgress> _sync =
      StreamController<SyncProgress>.broadcast();

  MqttLink _link = const MqttLink.connecting();

  String get _base => 'savein/$serial';
  String get telemetryTopic => '$_base/telemetry';
  String get eventTopic => '$_base/event';
  String get statusTopic => '$_base/status';
  String get syncTopic => '$_base/sync';
  String get cmdTopic => '$_base/cmd';

  // ---------------------------------------------------------------------------
  // 스트림 노출
  // ---------------------------------------------------------------------------

  /// 텔레메트리 → SensorReading (SensorService 계약).
  @override
  Stream<SensorReading> readings() => _telemetry.stream;

  /// 링크 상태(브로커/POD). 구독 즉시 현재값을 먼저 방출한다(리플레이).
  Stream<MqttLink> linkStream() async* {
    yield _link;
    yield* _links.stream;
  }

  /// POD 가 발행한 상태 전이 이벤트(→ 알림으로 편입).
  Stream<AlertEvent> eventStream() => _events.stream;

  /// SD 백필 진행 상태.
  Stream<SyncProgress> syncStream() => _sync.stream;

  MqttLink get link => _link;

  void _setLink(MqttLink l) {
    _link = l;
    if (!_links.isClosed) _links.add(l);
  }

  // ---------------------------------------------------------------------------
  // 연결
  // ---------------------------------------------------------------------------

  Future<void> connect() async {
    if (_disposed) return;
    _retry?.cancel();

    // 기존 클라이언트 정리 후 새로 생성.
    try {
      _client?.disconnect();
    } catch (_) {}

    final String clientId =
        'savein_app_${serial}_${DateTime.now().millisecondsSinceEpoch}';
    final MqttServerClient client =
        MqttServerClient.withPort(host, clientId, port);
    _client = client;
    client.keepAlivePeriod = 30;
    client.connectTimeoutPeriod = 4000;
    // 라이브러리 내부 autoReconnect 는 미처리 비동기 SocketException 을 던지므로 끄고,
    // 아래 _scheduleRetry() 로 직접(예외를 잡아가며) 재연결한다.
    client.autoReconnect = false;
    client.logging(on: false);
    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;
    client.connectionMessage =
        MqttConnectMessage().withClientIdentifier(clientId).startClean();

    _setLink(const MqttLink.connecting());
    try {
      if (username != null && username!.isNotEmpty) {
        await client.connect(username, password);
      } else {
        await client.connect();
      }
      client.updates?.listen(_onMessage);
    } catch (e) {
      debugPrint('[MQTT] connect 실패($host:$port): $e');
      _setLink(_link.copyWith(brokerConnected: false, error: '$e'));
      try {
        client.disconnect();
      } catch (_) {}
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (_disposed) return;
    _retry = Timer(const Duration(seconds: 5), () {
      if (!_disposed) connect();
    });
  }

  void _onConnected() {
    final MqttServerClient? c = _client;
    if (c == null || _disposed) return;
    _retry?.cancel();
    _setLink(_link.copyWith(brokerConnected: true, clearError: true));
    // retain 텔레메트리/상태를 즉시 받도록 구독한다.
    c.subscribe(telemetryTopic, MqttQos.atMostOnce);
    c.subscribe(statusTopic, MqttQos.atLeastOnce);
    c.subscribe(eventTopic, MqttQos.atLeastOnce);
    c.subscribe(syncTopic, MqttQos.atLeastOnce);
  }

  void _onDisconnected() {
    if (_disposed) return;
    _setLink(_link.copyWith(brokerConnected: false, pod: PodConnection.unknown));
    _scheduleRetry(); // autoReconnect 를 껐으므로 직접 재연결 예약
  }

  // ---------------------------------------------------------------------------
  // 수신 라우팅 + 파싱(방어적)
  // ---------------------------------------------------------------------------

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> batch) {
    for (final MqttReceivedMessage<MqttMessage> m in batch) {
      final String topic = m.topic;
      final MqttPublishMessage pub = m.payload as MqttPublishMessage;
      final String payload =
          MqttPublishPayload.bytesToStringAsString(pub.payload.message);
      try {
        if (topic == telemetryTopic) {
          _handleTelemetry(payload);
        } else if (topic == statusTopic) {
          _handleStatus(payload);
        } else if (topic == eventTopic) {
          _handleEvent(payload);
        } else if (topic == syncTopic) {
          _handleSync(payload);
        }
      } catch (e) {
        debugPrint('[MQTT] 파싱 실패($topic): $e · $payload');
      }
    }
  }

  /// 여러 키 이름 중 먼저 발견되는 수치값을 반환(펌웨어 필드명 유연성).
  static double? _pickNum(Map<String, dynamic> m, List<String> keys) {
    for (final String k in keys) {
      final Object? v = m[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final double? d = double.tryParse(v);
        if (d != null) return d;
      }
    }
    return null;
  }

  void _handleTelemetry(String payload) {
    final Object? decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) return;
    // 열사병 확률: 0~1 또는 0~100 으로 올 수 있어, 1 초과면 백분율로 간주해 정규화.
    final double heatRaw = _pickNum(decoded,
            ['heatstroke', 'heatstrokeRisk', 'heat_risk', 'risk', 'heat']) ??
        0;
    final double heat = (heatRaw > 1 ? heatRaw / 100 : heatRaw).clamp(0.0, 1.0);
    final SensorReading reading = SensorReading(
      time: DateTime.now(),
      temperatureC:
          _pickNum(decoded, ['tempC', 'temperatureC', 'temperature', 'temp']) ??
              0,
      humidity: _pickNum(decoded, ['humidity', 'hum', 'rh']) ?? 0,
      co2: _pickNum(decoded, ['co2', 'co2ppm', 'co2_ppm', 'eco2', 'CO2']) ?? 0,
      motion: _pickNum(decoded, ['motion', 'move', 'movement']) ?? 0,
      heatstrokeRisk: heat,
    );
    if (!_telemetry.isClosed) _telemetry.add(reading);
    // 텔레메트리가 오면 POD 는 온라인으로 간주.
    if (_link.pod != PodConnection.online) {
      _setLink(_link.copyWith(pod: PodConnection.online));
    }
  }

  void _handleStatus(String payload) {
    final String s = payload.trim().toLowerCase();
    PodConnection pod = PodConnection.unknown;
    if (s.contains('online')) {
      pod = PodConnection.online;
    } else if (s.contains('offline')) {
      pod = PodConnection.offline;
    } else {
      try {
        final Object? d = jsonDecode(payload);
        if (d is Map && d['status'] != null) {
          final String v = '${d['status']}'.toLowerCase();
          pod = v.contains('offline')
              ? PodConnection.offline
              : (v.contains('online')
                  ? PodConnection.online
                  : PodConnection.unknown);
        }
      } catch (_) {}
    }
    _setLink(_link.copyWith(pod: pod));
    if (pod == PodConnection.offline) {
      _emitEvent(AlertType.deviceOffline, AlertSeverity.warning, '기기 연결 끊김',
          'POD($serial)가 오프라인 상태예요');
    }
  }

  void _handleEvent(String payload) {
    final Object? d = jsonDecode(payload);
    if (d is! Map<String, dynamic>) return;
    final String type = '${d['type'] ?? d['event'] ?? 'event'}';
    final String sevStr =
        '${d['severity'] ?? d['level'] ?? 'info'}'.toLowerCase();
    final String message = '${d['message'] ?? d['msg'] ?? ''}';
    final AlertSeverity sev = sevStr.contains('crit')
        ? AlertSeverity.critical
        : (sevStr.contains('warn')
            ? AlertSeverity.warning
            : AlertSeverity.info);
    final AlertType at = _mapEventType(type);
    final String title = _eventTitle(at);
    _emitEvent(at, sev, title, message.isNotEmpty ? message : title);
  }

  AlertType _mapEventType(String t) {
    final String s = t.toLowerCase();
    if (s.contains('temp') || s.contains('heat')) {
      return AlertType.highTemperature;
    }
    if (s.contains('co2')) return AlertType.highCo2;
    if (s.contains('offline') || s.contains('disconnect')) {
      return AlertType.deviceOffline;
    }
    if (s.contains('prolong') || s.contains('long')) {
      return AlertType.prolongedOccupancy;
    }
    return AlertType.occupancyDetected;
  }

  String _eventTitle(AlertType t) => switch (t) {
        AlertType.highTemperature => '고온 감지',
        AlertType.highCo2 => 'CO₂ 농도 높음',
        AlertType.occupancyDetected => '탑승 감지',
        AlertType.prolongedOccupancy => '장시간 탑승',
        AlertType.deviceOffline => '기기 연결 끊김',
      };

  void _emitEvent(
      AlertType type, AlertSeverity sev, String title, String message) {
    if (_events.isClosed) return;
    _events.add(AlertEvent(
      id: 'M${serial}_${_evtSeq++}',
      type: type,
      severity: sev,
      time: DateTime.now(),
      title: title,
      message: message,
    ));
  }

  void _handleSync(String payload) {
    final Object? d = jsonDecode(payload);
    if (d is! Map<String, dynamic>) return;
    final String phase = '${d['phase'] ?? d['type'] ?? ''}'.toLowerCase();
    if (phase == 'info') {
      _syncTotal = (_pickNum(d, ['count', 'total', 'n']) ?? 0).toInt();
      _syncReceived = 0;
      _emitSync(false);
    } else if (phase == 'data') {
      final Object? samples = d['samples'] ?? d['data'];
      if (samples is List) _syncReceived += samples.length;
      // 백필 샘플은 라이브 추론 오염을 막기 위해 telemetry 스트림에 직접 넣지 않는다.
      _emitSync(false);
    } else if (phase == 'end') {
      _emitSync(true);
    }
  }

  void _emitSync(bool done) {
    if (_sync.isClosed) return;
    _sync.add(
        SyncProgress(received: _syncReceived, total: _syncTotal, done: done));
  }

  // ---------------------------------------------------------------------------
  // 명령 발행 (APP→POD, savein/{ID}/cmd)
  // ---------------------------------------------------------------------------

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  void _publish(String topic, Map<String, dynamic> json, {bool retain = false}) {
    final MqttServerClient? c = _client;
    if (c == null || !isConnected) {
      debugPrint('[MQTT] 발행 보류(미연결): $topic $json');
      return;
    }
    final MqttClientPayloadBuilder b = MqttClientPayloadBuilder()
      ..addString(jsonEncode(json));
    c.publishMessage(topic, MqttQos.atLeastOnce, b.payload!, retain: retain);
  }

  int get _nowSec => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// §5.1 차주 하차/탑승 토글 — retain 발행 권장. 마지막 상태가 브로커에 유지된다.
  /// aboard=false 이면 차주 하차(대시보드 '차주 하차' ON) 상태다.
  void publishOwnerAboard(bool aboard) => _publish(
        cmdTopic,
        <String, dynamic>{'cmd': 'owner_aboard', 'value': aboard, 'ts': _nowSec},
        retain: true,
      );

  /// SD 카드 백필 요청(sync 응답으로 수신).
  void requestBackfill({DateTime? since}) => _publish(
        cmdTopic,
        <String, dynamic>{
          'cmd': 'sync',
          if (since != null) 'since': since.millisecondsSinceEpoch ~/ 1000,
        },
      );

  /// 연결 확인용 핑.
  void ping() =>
      _publish(cmdTopic, <String, dynamic>{'cmd': 'ping', 'ts': _nowSec});

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
    _telemetry.close();
    _events.close();
    _links.close();
    _sync.close();
  }
}
