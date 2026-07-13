import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/services/ble_pairing_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_pill.dart';

/// BLE 페어링(6.2). Android/iOS 는 flutter_blue_plus 실제 스캔,
/// 웹/데스크톱/에뮬레이터(설정의 '목업 BLE 스캔')는 목업으로 동작한다.
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
  String? _error;

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
      _error = null;
    });
    _sub?.cancel();
    _sub = service.scan().listen(
      (List<DeviceInfo> list) {
        if (!mounted) return;
        setState(() => _found = list);
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _scanning = false;
          _error = e.toString();
        });
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

    try {
      final DeviceInfo connected = await service.connect(device);
      if (!mounted) return;
      ref.read(devicesProvider.notifier).add(connected);
      setState(() => _connectingId = null);
      messenger.showSnackBar(SnackBar(content: Text('${device.name} 연결됨')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _connectingId = null);
      messenger.showSnackBar(SnackBar(content: Text('연결 실패: $e')));
    }
  }

  /// 실제 BLE 실패 시(에뮬레이터 등) 목업 스캔으로 전환한다.
  void _fallbackToMock() {
    ref.read(settingsProvider.notifier).setUseMockBle(true);
    _startScan();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMock = ref.watch(blePairingIsMockProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('기기 페어링')),
      body: SafeArea(
        child: ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      '주변 센서 기기를 검색해 연결하세요.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                  StatusPill(
                    label: isMock ? '목업 모드' : '실제 BLE',
                    color: isMock ? AppColors.orange : AppColors.teal,
                    icon: isMock
                        ? Icons.science_outlined
                        : Icons.bluetooth_rounded,
                  ),
                ],
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
              if (_error != null)
                _ScanErrorCard(
                  message: _error!,
                  canFallback: !isMock,
                  onFallback: _fallbackToMock,
                )
              else if (_scanning && _found.isEmpty)
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
      ),
    );
  }
}

/// 스캔 실패 카드: 오류 메시지 + 목업 전환 버튼(에뮬레이터/미지원 기기용).
class _ScanErrorCard extends StatelessWidget {
  const _ScanErrorCard({
    required this.message,
    required this.canFallback,
    required this.onFallback,
  });

  final String message;
  final bool canFallback;
  final VoidCallback onFallback;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                '스캔에 실패했어요',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          if (canFallback) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              '에뮬레이터나 BLE 미지원 기기라면 목업 스캔으로 확인할 수 있어요.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onFallback,
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text('목업 스캔으로 전환'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.orange,
                side: const BorderSide(color: AppColors.orange),
              ),
            ),
          ],
        ],
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
    final String battery =
        device.hasBattery ? ' · 배터리 ${device.battery}%' : '';
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
                  '${device.sensorType.label}$battery',
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
