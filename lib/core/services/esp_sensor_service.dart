import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import 'sensor_service.dart';

/// ESP 보드 서버 기반 센서 소스(WiFi/HTTP 폴링).
///
/// 기대 엔드포인트(펌웨어 확정 전 가안):
///   GET {baseUrl}/api/sensor
///   → {"temperatureC": 27.5, "motion": 0.42}
///
/// TODO(esp): ESP 보드 펌웨어 스키마 확정 시 경로/필드명을 맞추고,
///  폴링 대신 WebSocket 푸시로 전환 검토.
class EspSensorService implements SensorService {
  EspSensorService({
    required this.baseUrl,
    Duration period = const Duration(seconds: 2),
  }) {
    _timer = Timer.periodic(period, (_) => _poll());
  }

  final String baseUrl;
  final http.Client _client = http.Client();
  final StreamController<SensorReading> _controller =
      StreamController<SensorReading>.broadcast();
  late final Timer _timer;
  bool _inFlight = false;

  Future<void> _poll() async {
    if (_inFlight || _controller.isClosed) return;
    _inFlight = true;
    try {
      final Uri uri = Uri.parse('$baseUrl/api/sensor');
      final http.Response res =
          await _client.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) {
        debugPrint('[ESP] HTTP ${res.statusCode} ($uri)');
        return;
      }
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      if (_controller.isClosed) return;
      _controller.add(
        SensorReading(
          time: DateTime.now(),
          temperatureC: (data['temperatureC'] as num).toDouble(),
          humidity: (data['humidity'] as num?)?.toDouble() ?? 0,
          motion: (data['motion'] as num?)?.toDouble() ?? 0,
        ),
      );
    } catch (e) {
      // 보드 미기동/네트워크 단절 시 스트림은 조용히 유지한다(모니터는 마지막 값 유지).
      debugPrint('[ESP] poll 실패: $e');
    } finally {
      _inFlight = false;
    }
  }

  @override
  Stream<SensorReading> readings() => _controller.stream;

  @override
  void dispose() {
    _timer.cancel();
    _client.close();
    _controller.close();
  }
}
