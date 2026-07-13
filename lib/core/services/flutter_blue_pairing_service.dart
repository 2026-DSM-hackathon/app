import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models.dart';
import 'ble_pairing_service.dart';

/// flutter_blue_plus 기반 실제 BLE 페어링(6.2).
///
/// Android 12+ 의 BLUETOOTH_SCAN/CONNECT 권한은 매니페스트에 선언되어 있고,
/// 스캔 시작 시 플러그인이 런타임 권한을 요청한다.
class FlutterBluePairingService implements BlePairingService {
  static const Duration _scanTimeout = Duration(seconds: 6);

  @override
  Stream<List<DeviceInfo>> scan() {
    final StreamController<List<DeviceInfo>> controller =
        StreamController<List<DeviceInfo>>();
    final Map<String, DeviceInfo> found = <String, DeviceInfo>{};
    StreamSubscription<List<ScanResult>>? sub;

    Future<void> run() async {
      try {
        if (!await FlutterBluePlus.isSupported) {
          throw StateError('이 기기는 블루투스 LE를 지원하지 않아요');
        }
        sub = FlutterBluePlus.scanResults.listen(
          (List<ScanResult> results) {
            for (final ScanResult r in results) {
              final String name = r.advertisementData.advName.isNotEmpty
                  ? r.advertisementData.advName
                  : r.device.platformName;
              if (name.isEmpty) continue; // 이름 없는 기기는 제외
              found[r.device.remoteId.str] = DeviceInfo(
                id: r.device.remoteId.str,
                name: name,
                battery: -1, // TODO(ble): Battery Service(0x180F) 읽어 표시
                connected: false,
                // TODO(ble): 광고 서비스 UUID → 센서 유형 매핑(펌웨어 확정 후)
                sensorType: SensorType.radar,
              );
            }
            if (!controller.isClosed) {
              controller.add(List<DeviceInfo>.unmodifiable(found.values));
            }
          },
          onError: controller.addError,
        );
        await FlutterBluePlus.startScan(timeout: _scanTimeout);
        // 스캔이 끝날 때까지 대기 후 스트림을 닫는다.
        await FlutterBluePlus.isScanning.where((bool s) => !s).first;
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      } finally {
        await sub?.cancel();
        if (!controller.isClosed) await controller.close();
      }
    }

    controller.onListen = run;
    controller.onCancel = FlutterBluePlus.stopScan;
    return controller.stream;
  }

  @override
  Future<DeviceInfo> connect(DeviceInfo device) async {
    final BluetoothDevice d = BluetoothDevice.fromId(device.id);
    await d.connect(
      // 개인/해커톤 용도의 비영리 사용. 상용 배포 시 flutter_blue_plus
      // 상용(License.commercial, 유료) 라이선스로 변경 필요.
      license: License.nonprofit,
      timeout: const Duration(seconds: 10),
    );
    return device.copyWith(connected: true);
  }
}
