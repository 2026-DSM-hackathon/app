import 'dart:async';

import '../models.dart';

/// BLE 페어링 인터페이스(6.2). 실제 구현은 flutter_blue_plus.
abstract interface class BlePairingService {
  /// 스캔 결과를 점진적으로 방출(누적 목록).
  Stream<List<DeviceInfo>> scan();

  /// 선택 기기 연결.
  Future<DeviceInfo> connect(DeviceInfo device);
}

/// 목업 페어링: 스캔 시 가짜 기기 목록을 순차적으로 방출한다.
///
/// TODO(real): flutter_blue_plus 의 scanResults 스트림과 device.connect() 로 교체.
class MockBlePairingService implements BlePairingService {
  static const List<DeviceInfo> _catalog = <DeviceInfo>[
    DeviceInfo(
      id: 'S-001',
      name: 'SeatGuard Radar A1',
      battery: 88,
      connected: false,
      sensorType: SensorType.radar,
    ),
    DeviceInfo(
      id: 'S-002',
      name: 'CabinThermal T2',
      battery: 64,
      connected: false,
      sensorType: SensorType.thermal,
    ),
    DeviceInfo(
      id: 'S-003',
      name: 'PressurePad P3',
      battery: 41,
      connected: false,
      sensorType: SensorType.pressure,
    ),
  ];

  @override
  Stream<List<DeviceInfo>> scan() async* {
    final List<DeviceInfo> found = <DeviceInfo>[];
    for (final DeviceInfo d in _catalog) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      found.add(d);
      yield List<DeviceInfo>.unmodifiable(found);
    }
  }

  @override
  Future<DeviceInfo> connect(DeviceInfo device) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return device.copyWith(connected: true);
  }
}
