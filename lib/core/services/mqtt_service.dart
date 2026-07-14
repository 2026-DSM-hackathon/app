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
/// JSON 스키마(펌웨어 §4·§5 확정본). 필드명은 방어적으로 파싱한다(여러 키 허용).
///   telemetry → {"ts":..,"t":24.13,"rh":52.3,"hi":23.97,"dist":1049,"co2":3396,
///                "cnt":0,"occ":0,"hint":0,"p":-1,"lv":0,"mode":0,"exp":0,
///                "batt":255,"seq":39,"fw":"0.1","flags":36}
///                t=온도 rh=습도 hi=열지수 co2=ppm dist=초음파mm(-1실패)
///                occ=재실(0/1) lv=위험단계0~4 exp=노출분 batt=배터리%(255=미측정)
///                p=AI 열사병확률 0~1(-1=미산출) · cnt/hint=의미 확인 필요(현재 미사용)
///   event     → {"ts":..,"code":3,"a":1,"b":0}  (code 별 의미는 §4.2)
///   status    → "online" / "offline" (평문, retain+LWT) 또는 {"status":"online"}
///   sync      → {"phase":"info","count":120} / {"phase":"data","samples":[...]} / {"phase":"end"}
///   cmd       → {"type":"config","owner_away":1} / {"type":"sync","since":...} (§5, 모든 명령에 type)
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
    final SensorReading reading = parseTelemetry(decoded);
    // 수신·파싱 확인용 로그(값이 제대로 매핑되는지 콘솔에서 검증).
    debugPrint('[MQTT] telemetry ← 온도 ${reading.temperatureC}°C · '
        '습도 ${reading.humidity}% · CO₂ ${reading.co2.toStringAsFixed(0)}ppm · '
        '재실 ${reading.occupancy ? "감지" : "없음"} · '
        '거리 ${reading.distanceMm ?? "-"}mm · '
        '열사병 ${(reading.heatstrokeRisk * 100).round()}%');
    if (!_telemetry.isClosed) _telemetry.add(reading);
    // 텔레메트리가 오면 POD 는 온라인으로 간주.
    if (_link.pod != PodConnection.online) {
      _setLink(_link.copyWith(pod: PodConnection.online));
    }
  }

  /// §4.1 telemetry JSON → SensorReading. 펌웨어 실제 키(t/rh/occ/dist/lv)를
  /// 파싱하되 구버전 가안 키도 허용한다. 순수 함수(테스트용으로 노출).
  @visibleForTesting
  static SensorReading parseTelemetry(Map<String, dynamic> m,
      {DateTime? now}) {
    // 온도(t)/습도(rh): §4.1 실제 키. 구버전 가안 키도 함께 허용.
    final double tempC =
        _pickNum(m, ['t', 'tempC', 'temperatureC', 'temperature', 'temp']) ?? 0;
    final double rh = _pickNum(m, ['rh', 'humidity', 'hum']) ?? 0;

    // CO₂: §4.1 telemetry 에는 아직 co2 필드가 없다. 펌웨어가 "co2":<ppm> 를
    // 추가하면 여기서 그대로 수신된다(그 전까지는 0 — 더미값 넣지 않음).
    final double co2 =
        _pickNum(m, ['co2', 'co2ppm', 'co2_ppm', 'eco2', 'CO2']) ?? 0;

    // 사람 감지(재실): §4.1 occ(0/1). 초음파 거리 dist(mm, -1=측정 실패).
    final double occRaw =
        _pickNum(m, ['occ', 'occupied', 'presence', 'motion', 'move']) ?? 0;
    final bool occupancy = occRaw >= 0.5;
    final double? distRaw = _pickNum(m, ['dist', 'distance', 'distanceMm']);
    final int? distanceMm =
        (distRaw == null || distRaw < 0) ? null : distRaw.toInt();

    // 열사병 확률: AI 확률 p(0~1, 또는 0~100)를 우선 사용한다. p=-1(미산출) 등
    // 음수면 아직 값이 없다는 뜻이므로, 규칙 기반 위험단계 lv(0~4)→0~1 로 폴백한다.
    // (AI 미가동 시에도 0% 대신 실측 위험단계를 보여주는 편이 안전하다.)
    final double? hsRaw = _pickNum(
        m, ['heatstroke', 'heatstrokeRisk', 'heat_risk', 'hs', 'risk', 'p']);
    final double heat;
    if (hsRaw != null && hsRaw >= 0) {
      heat = (hsRaw > 1 ? hsRaw / 100 : hsRaw).clamp(0.0, 1.0);
    } else {
      final double? lv = _pickNum(m, ['lv', 'level']);
      heat = lv != null ? (lv / 4).clamp(0.0, 1.0) : 0;
    }

    return SensorReading(
      time: now ?? DateTime.now(),
      temperatureC: tempC,
      humidity: rh,
      co2: co2,
      // 추론 엔진 호환: 재실(occ)을 움직임 강도로도 반영(1.0/0.0).
      motion: occupancy ? 1.0 : 0.0,
      occupancy: occupancy,
      distanceMm: distanceMm,
      heatstrokeRisk: heat,
    );
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

  void _publish(String topic, Map<String, dynamic> json,
      {bool retain = false, String? note}) {
    final String tag = note != null ? ' · $note' : '';
    final MqttServerClient? c = _client;
    if (c == null || !isConnected) {
      debugPrint('[MQTT] cmd 발행 보류(미연결)$tag → $topic ${jsonEncode(json)}');
      return;
    }
    final MqttClientPayloadBuilder b = MqttClientPayloadBuilder()
      ..addString(jsonEncode(json));
    c.publishMessage(topic, MqttQos.atLeastOnce, b.payload!, retain: retain);
    debugPrint('[MQTT] cmd 발행 → $opic '
        '(QoS1${retain ? ', retain' : ''})$tag ${jsonEncode(json)}');
  }

  int get _nowSec => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// §5.1 차주 하차 토글 → config.owner_away 명령(부분 갱신).
  /// away=true(차주 하차, 대시보드 토글 ON) → owner_away=1(감시 시작/on).
  /// away=false(차주 탑승, 토글 OFF)      → owner_away=0(해제/off).
  static Map<String, dynamic> ownerAwayCommand(bool away) =>
      <String, dynamic>{'type': 'config', 'owner_away': away ? 1 : 0};

  /// 차주 하차 상태를 cmd 로 발행한다. retain 이라 브로커에 마지막 상태가 남아
  /// 기기가 (재)접속하면 즉시 최신 owner_away 를 받는다.
  void publishOwnerAway(bool away) {
    _publish(cmdTopic, ownerAwayCommand(away),
        retain: true, note: '차주 하차 ${away ? "ON" : "OFF"}');
  }

  /// SD 카드 백필 요청(§6 sync 응답으로 수신). 모든 명령은 type 필드를 갖는다(§5).
  void requestBackfill({DateTime? since}) => _publish(
        cmdTopic,
        <String, dynamic>{
          'type': 'sync',
          if (since != null) 'since': since.millisecondsSinceEpoch ~/ 1000,
        },
        note: 'SD 백필 요청',
      );

  /// 연결 확인용 핑(POD 는 알 수 없는 type 을 무시하므로 브로커 왕복 확인용).
  void ping() => _publish(
        cmdTopic,
        <String, dynamic>{'type': 'ping', 'ts': _nowSec},
        note: '핑',
      );

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
