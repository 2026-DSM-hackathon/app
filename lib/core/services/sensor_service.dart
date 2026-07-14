import 'dart:async';
import 'dart:math';

import '../models.dart';

/// 센서 데이터 소스 인터페이스. 실제 구현은 MQTT(savein/{serial}/telemetry)로 교체.
abstract interface class SensorService {
  Stream<SensorReading> readings();
  void dispose();
}

/// 목업 센서: 주기적으로 합성 온도/습도/CO2/움직임 샘플을 방출한다.
///
/// TODO(real): MqttSensorService 가 savein/{serial}/telemetry 를 파싱해 방출하는
/// 실측 스트림으로 대체된다(설정의 데이터 소스 = MQTT).
class MockSensorService implements SensorService {
  MockSensorService() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _emit());
  }

  final StreamController<SensorReading> _controller =
      StreamController<SensorReading>.broadcast();
  final Random _rnd = Random();
  late final Timer _timer;

  double _baseTemp = 26;
  double _baseHumidity = 55;
  double _baseCo2 = 650; // ppm (외기 ~400, 실내 밀폐 시 상승)
  final double _occupancyBias = 0.6; // 데모: 탑승 경향

  void _emit() {
    // 온도는 완만히 변동하되 가끔 상승(고온 시나리오).
    _baseTemp += (_rnd.nextDouble() - 0.45) * 1.4;
    _baseTemp = _baseTemp.clamp(18.0, 55.0);

    // 움직임: 탑승 중이면 간헐적으로 큰 값.
    final bool occupiedNow = _rnd.nextDouble() < _occupancyBias;
    final double motion =
        occupiedNow ? (0.4 + _rnd.nextDouble() * 0.6) : (_rnd.nextDouble() * 0.15);

    // 습도도 완만히 변동.
    _baseHumidity += (_rnd.nextDouble() - 0.5) * 4;
    _baseHumidity = _baseHumidity.clamp(30.0, 90.0);

    // CO2: 사람 호흡(움직임) 중이면 상승, 비어있으면 서서히 환기(하강).
    _baseCo2 += occupiedNow
        ? (30 + _rnd.nextDouble() * 90)
        : (-40 + _rnd.nextDouble() * 30);
    _baseCo2 = _baseCo2.clamp(400.0, 2600.0);

    // 열사병 확률: 실내 온도(+습도)에 따라 상승. POD telemetry 값의 목업.
    final double heat = (((_baseTemp - 28) / 20) +
            (_baseHumidity - 50) / 200 +
            (_rnd.nextDouble() - 0.5) * 0.05)
        .clamp(0.0, 1.0);

    _controller.add(
      SensorReading(
        time: DateTime.now(),
        temperatureC: double.parse(_baseTemp.toStringAsFixed(1)),
        humidity: double.parse(_baseHumidity.toStringAsFixed(0)),
        co2: double.parse(_baseCo2.toStringAsFixed(0)),
        motion: double.parse(motion.toStringAsFixed(2)),
        occupancy: occupiedNow,
        heatstrokeRisk: double.parse(heat.toStringAsFixed(2)),
      ),
    );
  }

  @override
  Stream<SensorReading> readings() => _controller.stream;

  @override
  void dispose() {
    _timer.cancel();
    _controller.close();
  }
}
