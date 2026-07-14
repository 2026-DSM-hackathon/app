// MQTT 텔레메트리 수신 확인용 CLI 프로브.
//
// 앱을 켜지 않고도 브로커에 실제 telemetry 가 오는지, 값이 올바로 파싱되는지
// 콘솔에서 검증한다. 앱(MqttSensorService.parseTelemetry)과 동일한 키 매핑을 쓴다.
//
// 실행:
//   dart run tool/mqtt_probe.dart [host] [serial] [port] [seconds]
// 예:
//   dart run tool/mqtt_probe.dart broker.emqx.io SVN-EED364 1883 25
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

Future<void> main(List<String> args) async {
  final String host = args.isNotEmpty ? args[0] : 'broker.emqx.io';
  final String serial = args.length > 1 ? args[1] : 'SVN-EED364';
  final int port = args.length > 2 ? int.tryParse(args[2]) ?? 1883 : 1883;
  final int seconds = args.length > 3 ? int.tryParse(args[3]) ?? 20 : 20;
  final String base = 'savein/$serial';
  final String sub = '$base/#'; // 5개 토픽(telemetry/event/status/sync/cmd) 전부 감시
  final String telemetryTopic = '$base/telemetry';

  final MqttServerClient client = MqttServerClient.withPort(
      host, 'probe_${DateTime.now().millisecondsSinceEpoch}', port);
  client.keepAlivePeriod = 20;
  client.connectTimeoutPeriod = 5000;
  client.autoReconnect = false;
  client.logging(on: false);

  stdout.writeln('· 브로커 $host:$port 접속 시도 → $sub (${seconds}s)');
  try {
    await client.connect();
  } catch (e) {
    stderr.writeln('✗ 접속 실패: $e');
    client.disconnect();
    exit(1);
  }
  if (client.connectionStatus?.state != MqttConnectionState.connected) {
    stderr.writeln('✗ 접속 실패: ${client.connectionStatus}');
    exit(1);
  }
  stdout.writeln('✓ 브로커 접속 완료 — 수신 대기(retain 이면 즉시 도착)');

  int count = 0;
  final bool selftest = args.contains('selftest');
  client.subscribe(sub, MqttQos.atLeastOnce);

  // self-test: 파이프가 살아있는지 확인용으로 표본을 스스로 발행해 되받는다.
  if (selftest) {
    Timer(const Duration(milliseconds: 1200), () {
      const String sample =
          '{"ts":1784023999,"t":24.13,"rh":52.30,"hi":23.97,"dist":1049,'
          '"co2":3396,"cnt":0,"occ":0,"hint":0,"p":-1,"lv":0,"mode":0,'
          '"exp":0,"batt":255,"seq":39,"fw":"0.1","flags":36}';
      final MqttClientPayloadBuilder b = MqttClientPayloadBuilder()
        ..addString(sample);
      client.publishMessage(telemetryTopic, MqttQos.atLeastOnce, b.payload!);
      stdout.writeln('· (self-test) 표본 발행 → $telemetryTopic');
    });
  }
  client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> batch) {
    for (final MqttReceivedMessage<MqttMessage> m in batch) {
      final String payload = MqttPublishPayload.bytesToStringAsString(
          (m.payload as MqttPublishMessage).payload.message);
      count++;
      final String leaf = m.topic.split('/').last; // telemetry/event/status/sync/cmd
      stdout.writeln('\n[$count] $leaf ← $payload');
      // cmd(앱→기기) 는 owner_away 등 명령이므로 눈에 띄게 표기한다.
      if (leaf == 'cmd') {
        stdout.writeln('    ↳ 앱이 보낸 명령(cmd) 확인!');
        continue;
      }
      if (leaf != 'telemetry') continue; // event/status/sync 는 원문만 표기
      try {
        final Object? d = jsonDecode(payload);
        if (d is Map<String, dynamic>) {
          stdout.writeln('    파싱: ${_summarize(d)}');
        }
      } catch (e) {
        stdout.writeln('    ✗ JSON 파싱 실패: $e');
      }
    }
  });

  await Future<void>.delayed(Duration(seconds: seconds));
  client.disconnect();
  stdout.writeln(count == 0
      ? '\n✗ ${seconds}s 동안 메시지 없음 — 브로커 host/serial 을 확인하세요.'
      : '\n✓ 총 $count건 수신 — 통신 정상.');
  exit(count == 0 ? 2 : 0);
}

// 앱 MqttSensorService.parseTelemetry 와 동일한 키 매핑(검증용 요약).
String _summarize(Map<String, dynamic> m) {
  double? pick(List<String> keys) {
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

  final double t = pick(['t', 'tempC', 'temperatureC', 'temperature', 'temp']) ?? 0;
  final double rh = pick(['rh', 'humidity', 'hum']) ?? 0;
  final double co2 = pick(['co2', 'co2ppm', 'co2_ppm', 'eco2', 'CO2']) ?? 0;
  final double occ = pick(['occ', 'occupied', 'presence', 'motion', 'move']) ?? 0;
  final double? dist = pick(['dist', 'distance', 'distanceMm']);
  final double? hs = pick(['heatstroke', 'heatstrokeRisk', 'heat_risk', 'hs', 'risk', 'p']);
  final double? lv = pick(['lv', 'level']);
  final double heat = (hs != null && hs >= 0)
      ? (hs > 1 ? hs / 100 : hs).clamp(0.0, 1.0)
      : (lv != null ? (lv / 4).clamp(0.0, 1.0) : 0);

  return '온도 $t°C · 습도 $rh% · CO₂ ${co2.toStringAsFixed(0)}ppm · '
      '재실 ${occ >= 0.5 ? "감지" : "없음"} · '
      '거리 ${(dist == null || dist < 0) ? "실패" : "${dist.toInt()}mm"} · '
      '열사병 ${(heat * 100).round()}%';
}
