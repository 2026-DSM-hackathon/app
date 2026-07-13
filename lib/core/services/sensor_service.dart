import 'dart:async';
import 'dart:math';

import '../models.dart';

/// 센서 데이터 소스 인터페이스. 실제 구현은 BLE(flutter_blue_plus GATT notify)로 교체.
abstract interface class SensorService {
  Stream<SensorReading> readings();
  void dispose();
}

/// 목업 센서: 주기적으로 합성 온도/움직임 샘플을 방출한다.
///
/// TODO(real): flutter_blue_plus 로 연결된 센서의 characteristic notify 스트림을
/// SensorReading 으로 매핑해 교체.
class MockSensorService implements SensorService {
  MockSensorService() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _emit());
  }

  final StreamController<SensorReading> _controller =
      StreamController<SensorReading>.broadcast();
  final Random _rnd = Random();
  late final Timer _timer;

  double _baseTemp = 26;
  final double _occupancyBias = 0.6; // 데모: 탑승 경향

  void _emit() {
    // 온도는 완만히 변동하되 가끔 상승(고온 시나리오).
    _baseTemp += (_rnd.nextDouble() - 0.45) * 1.4;
    _baseTemp = _baseTemp.clamp(18.0, 55.0);

    // 움직임: 탑승 중이면 간헐적으로 큰 값.
    final bool occupiedNow = _rnd.nextDouble() < _occupancyBias;
    final double motion =
        occupiedNow ? (0.4 + _rnd.nextDouble() * 0.6) : (_rnd.nextDouble() * 0.15);

    _controller.add(
      SensorReading(
        time: DateTime.now(),
        temperatureC: double.parse(_baseTemp.toStringAsFixed(1)),
        motion: double.parse(motion.toStringAsFixed(2)),
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
