import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/services/ble_pairing_service.dart';
import '../../widgets/app_card.dart';

// TODO(real): flutter_blue_plus 로 실제 스캔/연결로 교체.

/// BLE 페어링(6.2, mock). 스캔 → 목록 → 연결 플로우.
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  bool _scanning = false;
  List<DeviceInfo> _found = <DeviceInfo>[];
  StreamSubscription<List<DeviceInfo>>? _sub;
  String? _connectingId;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _startScan() {
    final BlePairingService service = ref.read(blePairingServiceProvider);
    setState(() {
      _scanning = true;
      _found = <DeviceInfo>[];
    });
    _sub?.cancel();
    _sub = service.scan().listen(
      (List<DeviceInfo> list) {
        if (!mounted) return;
        setState(() => _found = list);
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _scanning = false);
      },
    );
  }

  Future<void> _connect(DeviceInfo device) async {
    final BlePairingService service = ref.read(blePairingServiceProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _connectingId = device.id);

    final DeviceInfo connected = await service.connect(device);

    if (!mounted) return;
    ref.read(devicesProvider.notifier).add(connected);
    setState(() => _connectingId = null);
    messenger.showSnackBar(SnackBar(content: Text('${device.name} 연결됨')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기기 페어링')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: <Widget>[
            const Text(
              '주변 센서 기기를 검색해 연결하세요.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _scanning ? null : _startScan,
                icon: const Icon(Icons.bluetooth_searching),
                label: Text(_scanning ? '검색 중…' : '스캔 시작'),
              ),
            ),
            const SizedBox(height: 24),
            if (_scanning && _found.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final DeviceInfo device in _found) ...<Widget>[
                _DeviceTile(
                  device: device,
                  connecting: _connectingId == device.id,
                  onConnect: () => _connect(device),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.connecting,
    required this.onConnect,
  });

  final DeviceInfo device;
  final bool connecting;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: <Widget>[
          const Icon(Icons.sensors, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  device.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${device.sensorType.label} · 배터리 ${device.battery}%',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          connecting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FilledButton(
                  onPressed: onConnect,
                  child: const Text('연결'),
                ),
        ],
      ),
    );
  }
}
