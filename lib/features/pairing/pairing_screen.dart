import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_pill.dart';

/// 기기 연결(6.2). BLE 스캔 대신 **시리얼 넘버**로 MQTT 브로커에 연결한다.
///
/// 등록하면 데이터 소스를 MQTT 로 전환하고 savein/{시리얼}/* 토픽을 구독한다.
/// telemetry 는 retain 이라 구독 즉시 마지막 상태를 받는다.
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  late final TextEditingController _serial;
  late final TextEditingController _host;
  late final TextEditingController _port;
  String? _error;

  @override
  void initState() {
    super.initState();
    final SettingsState s = ref.read(settingsProvider);
    _serial = TextEditingController(text: s.deviceSerial);
    _host = TextEditingController(text: s.mqttHost);
    _port = TextEditingController(text: '${s.mqttPort}');
  }

  @override
  void dispose() {
    _serial.dispose();
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  void _register() {
    final String serial = _serial.text.trim();
    final String host = _host.text.trim();
    final int? port = int.tryParse(_port.text.trim());
    if (serial.isEmpty || host.isEmpty) {
      setState(() => _error = '시리얼 넘버와 브로커 호스트를 입력하세요.');
      return;
    }
    if (port == null || port <= 0 || port >= 65536) {
      setState(() => _error = '포트 번호가 올바르지 않아요(1–65535).');
      return;
    }
    setState(() => _error = null);

    // 설정을 원자적으로 적용해 연속 상태 변경으로 인한 빌드 중 재진입을 피한다.
    ref.read(settingsProvider.notifier).applyMqttConfig(
          serial: serial,
          host: host,
          port: port,
        );

    ref.read(devicesProvider.notifier).add(
          DeviceInfo(
            id: serial,
            name: 'SAVEIN Pod',
            battery: -1,
            connected: true,
            sensorType: SensorType.radar,
          ),
        );

    FocusScope.of(context).unfocus();
    // 스낵바는 프로바이더 전파와 겹치지 않도록 다음 프레임에 표시한다.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('$serial 등록 완료 — MQTT 연결을 시작합니다')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final SettingsState settings = ref.watch(settingsProvider);
    final bool isMqtt = settings.sensorSource == SensorDataSource.mqtt;

    return Scaffold(
      appBar: AppBar(title: const Text('기기 연결')),
      body: SafeArea(
        child: ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      '기기 시리얼 넘버로 MQTT 서버에 연결해요.\nsavein/{시리얼}/* 토픽으로 실시간 통신합니다.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  StatusPill(
                    label: isMqtt ? 'MQTT' : settings.sensorSource.label,
                    color: isMqtt ? AppColors.teal : AppColors.orange,
                    icon: Icons.lan_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _Field(
                      label: '시리얼 넘버',
                      controller: _serial,
                      hint: '예: SAVEIN-0001',
                      icon: Icons.qr_code_2_rounded,
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      label: 'MQTT 브로커 호스트',
                      controller: _host,
                      hint: '예: test.mosquitto.org',
                      icon: Icons.dns_outlined,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      label: '포트',
                      controller: _port,
                      hint: '평문 1883 / TLS 8883',
                      icon: Icons.settings_ethernet_rounded,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style:
                            const TextStyle(color: AppColors.red, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _register,
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('등록하고 연결'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (isMqtt) const _ConnectionCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 라벨 + 아이콘 입력 필드.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.textTertiary, fontSize: 13),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

/// 연결 상태 카드: 브로커/POD 상태 + retain 으로 즉시 받은 최신 상태값.
class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(mqttLinkProvider).asData?.value;
    final bool broker = l?.brokerConnected ?? false;
    final PodConnection pod = l?.pod ?? PodConnection.unknown;
    final MonitorState monitor = ref.watch(monitorProvider);
    final bool hasData = monitor.latest != null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '연결 상태',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              StatusPill(
                label: broker ? '브로커 연결됨' : '브로커 연결 중…',
                color: broker ? AppColors.teal : AppColors.orange,
                icon:
                    broker ? Icons.cloud_done_outlined : Icons.cloud_sync_outlined,
              ),
              const SizedBox(width: 8),
              StatusPill(
                label: 'POD ${pod.label}',
                color: switch (pod) {
                  PodConnection.online => AppColors.green,
                  PodConnection.offline => AppColors.red,
                  PodConnection.unknown => AppColors.textTertiary,
                },
                icon: Icons.sensors,
              ),
            ],
          ),
          const Divider(color: AppColors.divider, height: 26),
          if (!hasData)
            const Text(
              '텔레메트리 수신 대기 중… (retain 이면 구독 즉시 마지막 상태가 도착해요)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _MiniStat(
                    label: '온도',
                    value: monitor.temperatureC.toStringAsFixed(1),
                    unit: '°C',
                    color: AppColors.teal),
                _MiniStat(
                    label: '습도',
                    value: monitor.humidity.toStringAsFixed(0),
                    unit: '%',
                    color: AppColors.blue),
                _MiniStat(
                    label: 'CO₂',
                    value: monitor.co2.toStringAsFixed(0),
                    unit: 'ppm',
                    color: monitor.co2.airQuality.color),
              ],
            ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: <TextSpan>[
              TextSpan(
                text: value,
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
