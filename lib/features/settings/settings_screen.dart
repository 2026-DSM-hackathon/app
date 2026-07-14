import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';

/// 설정(6.7, F-09/10): 알림 임계값 · 비상 연락처 · 기기 관리 · 센서 유형.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SettingsState settings = ref.watch(settingsProvider);
    final List<DeviceInfo> devices = ref.watch(devicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: <Widget>[
            const SectionHeader(title: '알림 임계값'),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _ThresholdSlider(
                    label: '고온 임계값',
                    valueLabel:
                        '${settings.tempThresholdC.toStringAsFixed(0)}°C',
                    value: settings.tempThresholdC,
                    min: 30,
                    max: 55,
                    divisions: 25,
                    onChanged: (double v) =>
                        ref.read(settingsProvider.notifier).setTempThreshold(v),
                  ),
                  const SizedBox(height: 8),
                  _ThresholdSlider(
                    label: 'CO₂ 임계값',
                    valueLabel:
                        '${settings.co2ThresholdPpm.toStringAsFixed(0)}ppm',
                    value: settings.co2ThresholdPpm,
                    min: 800,
                    max: 2500,
                    divisions: 17,
                    onChanged: (double v) =>
                        ref.read(settingsProvider.notifier).setCo2Threshold(v),
                  ),
                  const SizedBox(height: 8),
                  _ThresholdSlider(
                    label: '장시간 탑승 임계값',
                    valueLabel:
                        '${(settings.elapsedThresholdSec / 60).toStringAsFixed(1)}분',
                    value: settings.elapsedThresholdSec.toDouble(),
                    min: 30,
                    max: 600,
                    divisions: 19,
                    onChanged: (double v) => ref
                        .read(settingsProvider.notifier)
                        .setElapsedThreshold(v.round()),
                  ),
                  const SizedBox(height: 8),
                  _ThresholdSlider(
                    label: '감지 확률 임계값',
                    valueLabel:
                        '${(settings.probabilityThreshold * 100).round()}%',
                    value: settings.probabilityThreshold,
                    min: 0.1,
                    max: 0.9,
                    divisions: 8,
                    onChanged: (double v) => ref
                        .read(settingsProvider.notifier)
                        .setProbabilityThreshold(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: '비상 연락처'),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (settings.emergencyContacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '등록된 연락처가 없어요',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    for (int i = 0; i < settings.emergencyContacts.length; i++)
                      ...<Widget>[
                        if (i > 0)
                          const Divider(color: AppColors.divider, height: 20),
                        _ContactRow(
                          contact: settings.emergencyContacts[i],
                          onDelete: () => ref
                              .read(settingsProvider.notifier)
                              .removeContact(i),
                        ),
                      ],
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _showAddContactDialog(context, ref),
                      icon: const Icon(Icons.add, color: AppColors.primary),
                      label: const Text(
                        '연락처 추가',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: '기기 관리'),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (devices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '페어링된 기기가 없어요',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    for (int i = 0; i < devices.length; i++) ...<Widget>[
                      if (i > 0)
                        const Divider(color: AppColors.divider, height: 20),
                      _DeviceRow(
                        device: devices[i],
                        onDelete: () => ref
                            .read(devicesProvider.notifier)
                            .remove(devices[i].id),
                      ),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: '센서 유형'),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (devices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '표시할 기기가 없어요',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    for (int i = 0; i < devices.length; i++) ...<Widget>[
                      if (i > 0)
                        const Divider(color: AppColors.divider, height: 20),
                      _SensorTypeRow(device: devices[i]),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: '데이터 소스'),
            const SizedBox(height: 12),
            _DataSourceCard(settings: settings),
            const SizedBox(height: 22),
            const SectionHeader(title: '알림'),
            const SizedBox(height: 12),
            const _NotificationCard(),
          ],
        ),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddContactDialog(
        onSave: (EmergencyContact contact) =>
            ref.read(settingsProvider.notifier).addContact(contact),
      ),
    );
  }
}

/// 임계값 슬라이더 1행: 라벨 + 현재 값(우측), 그 아래 Slider.
class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          activeColor: AppColors.primary,
          inactiveColor: AppColors.divider,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// 비상 연락처 1행: 이름(볼드) + 전화번호 + 삭제 버튼.
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.onDelete});

  final EmergencyContact contact;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                contact.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                contact.phone,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onDelete,
          tooltip: '연락처 삭제',
          icon: const Icon(Icons.delete_outline, color: AppColors.red),
        ),
      ],
    );
  }
}

/// 페어링된 기기 1행: 이름(볼드) + 배터리/연결 상태 + 삭제 버튼.
class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.onDelete});

  final DeviceInfo device;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                device.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '배터리 ${device.hasBattery ? '${device.battery}%' : '—'} · ${device.connected ? '연결됨' : '연결 안됨'}',
                style: TextStyle(
                  color: device.connected
                      ? AppColors.textSecondary
                      : AppColors.orange,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onDelete,
          tooltip: '기기 삭제',
          icon: const Icon(Icons.delete_outline, color: AppColors.red),
        ),
      ],
    );
  }
}

/// 센서 유형 1행(F-10 표시): 기기 이름 + 센서 유형 StatusPill.
class _SensorTypeRow extends StatelessWidget {
  const _SensorTypeRow({required this.device});

  final DeviceInfo device;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            device.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        StatusPill(label: device.sensorType.label, color: AppColors.teal),
      ],
    );
  }
}

/// 비상 연락처 추가 다이얼로그(이름/전화번호 입력).
class _AddContactDialog extends StatefulWidget {
  const _AddContactDialog({required this.onSave});

  final ValueChanged<EmergencyContact> onSave;

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    final String name = _nameController.text.trim();
    final String phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      return;
    }
    widget.onSave(EmergencyContact(name: name, phone: phone));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      title: const Text(
        '연락처 추가',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _nameController,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: '이름',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: '전화번호',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            '취소',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: const Text(
            '저장',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

/// 알림 카드: 열사병 경보 로컬 알림 권한 허용 토글.
class _NotificationCard extends ConsumerWidget {
  const _NotificationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool enabled = ref.watch(notificationEnabledProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('알림 허용',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text('열사병 경보를 기기에서 직접 팝업으로 알립니다',
                        style: TextStyle(
                            color: AppColors.textTertiary, fontSize: 11)),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeThumbColor: AppColors.primary,
                onChanged: (bool v) async {
                  final ScaffoldMessengerState messenger =
                      ScaffoldMessenger.of(context);
                  if (v) {
                    final bool granted = await ref
                        .read(notificationServiceProvider)
                        .requestPermission();
                    ref
                        .read(notificationEnabledProvider.notifier)
                        .set(granted);
                    messenger.showSnackBar(SnackBar(
                        content: Text(granted
                            ? '알림이 허용되었습니다'
                            : '알림 권한이 거부되었습니다. 기기 설정에서 허용해 주세요')));
                  } else {
                    ref.read(notificationEnabledProvider.notifier).set(false);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 데이터 소스 카드: 센서 소스(목업/ESP/MQTT) 전환 + 소스별 설정.
///
/// MQTT: savein/{시리얼}/telemetry|event|status|sync|cmd 로 하드웨어와 통신.
/// TODO(fw): telemetry/cmd JSON 스키마는 임시 가안(§5·§5.1 확정 시 조정).
class _DataSourceCard extends ConsumerWidget {
  const _DataSourceCard({required this.settings});

  final SettingsState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isEsp = settings.sensorSource == SensorDataSource.esp;
    final bool isMqtt = settings.sensorSource == SensorDataSource.mqtt;
    final SettingsNotifier notifier = ref.read(settingsProvider.notifier);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '센서 데이터',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final SensorDataSource source in SensorDataSource.values)
                ChoiceChip(
                  label: Text(source.label),
                  selected: settings.sensorSource == source,
                  showCheckmark: false,
                  onSelected: (_) => notifier.setSensorSource(source),
                  backgroundColor: AppColors.surfaceAlt,
                  selectedColor: AppColors.primary,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  labelStyle: TextStyle(
                    color: settings.sensorSource == source
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (isEsp) ...<Widget>[
            const SizedBox(height: 14),
            _SourceValueRow(
              label: 'ESP 서버 주소',
              value: settings.espBaseUrl,
              tooltip: 'ESP 주소 수정',
              onEdit: () => _editField(
                context,
                title: 'ESP 서버 주소',
                hint: '예: http://192.168.0.42',
                initial: settings.espBaseUrl,
                keyboardType: TextInputType.url,
                onSave: notifier.setEspBaseUrl,
              ),
            ),
          ],
          if (isMqtt) ...<Widget>[
            const SizedBox(height: 14),
            _SourceValueRow(
              label: 'MQTT 브로커',
              value: '${settings.mqttHost}:${settings.mqttPort}',
              tooltip: '브로커 수정',
              onEdit: () => _editField(
                context,
                title: 'MQTT 브로커 호스트',
                hint: '예: test.mosquitto.org',
                initial: settings.mqttHost,
                keyboardType: TextInputType.url,
                onSave: notifier.setMqttHost,
              ),
            ),
            const Divider(color: AppColors.divider, height: 20),
            _SourceValueRow(
              label: '포트',
              value: '${settings.mqttPort}',
              tooltip: '포트 수정',
              onEdit: () => _editField(
                context,
                title: 'MQTT 포트',
                hint: '평문 1883 / TLS 8883',
                initial: '${settings.mqttPort}',
                keyboardType: TextInputType.number,
                onSave: (String v) {
                  final int? p = int.tryParse(v.trim());
                  if (p != null && p > 0 && p < 65536) notifier.setMqttPort(p);
                },
              ),
            ),
            const Divider(color: AppColors.divider, height: 20),
            _SourceValueRow(
              label: '기기 시리얼 넘버',
              value: settings.deviceSerial,
              tooltip: '시리얼 수정',
              onEdit: () => _editField(
                context,
                title: '기기 시리얼 넘버',
                hint: '예: SAVEIN-0001',
                initial: settings.deviceSerial,
                onSave: notifier.setDeviceSerial,
              ),
            ),
            const SizedBox(height: 12),
            const _MqttStatusRow(),
          ],
          const SizedBox(height: 10),
          Text(
            isMqtt
                ? '토픽: savein/${settings.deviceSerial}/telemetry · event · status · sync · cmd (§5 스키마 확정 시 조정)'
                : 'ESP 보드: GET {주소}/api/sensor → {"temperatureC","humidity","co2","motion"} · 펌웨어 확정 후 조정',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _editField(
    BuildContext context, {
    required String title,
    required String hint,
    required String initial,
    required ValueChanged<String> onSave,
    TextInputType? keyboardType,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => _EditFieldDialog(
        title: title,
        hint: hint,
        initial: initial,
        keyboardType: keyboardType,
        onSave: onSave,
      ),
    );
  }
}

/// 라벨 + 현재 값 + 수정 버튼(데이터 소스 설정 공용 행).
class _SourceValueRow extends StatelessWidget {
  const _SourceValueRow({
    required this.label,
    required this.value,
    required this.tooltip,
    required this.onEdit,
  });

  final String label;
  final String value;
  final String tooltip;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: tooltip,
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined,
              color: AppColors.textSecondary, size: 20),
        ),
      ],
    );
  }
}

/// MQTT 링크 상태 행: 브로커 연결 + POD 온라인 여부(pill 2개).
class _MqttStatusRow extends ConsumerWidget {
  const _MqttStatusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(mqttLinkProvider).asData?.value;
    final bool broker = l?.brokerConnected ?? false;
    final PodConnection pod = l?.pod ?? PodConnection.unknown;
    final String? error = l?.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            StatusPill(
              label: broker ? '브로커 연결됨' : '브로커 연결 중…',
              color: broker ? AppColors.teal : AppColors.orange,
              icon: broker ? Icons.cloud_done_outlined : Icons.cloud_sync_outlined,
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
        if (error != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            '연결 오류: $error',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.red, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

/// 데이터 소스 값(주소/호스트/포트/시리얼) 수정 다이얼로그.
class _EditFieldDialog extends StatefulWidget {
  const _EditFieldDialog({
    required this.title,
    required this.hint,
    required this.initial,
    required this.onSave,
    this.keyboardType,
  });

  final String title;
  final String hint;
  final String initial;
  final ValueChanged<String> onSave;
  final TextInputType? keyboardType;

  @override
  State<_EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<_EditFieldDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final String v = _controller.text.trim();
    if (v.isEmpty) return;
    widget.onSave(v);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(color: AppColors.textPrimary),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: widget.hint,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.divider),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            '취소',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: const Text(
            '저장',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}
