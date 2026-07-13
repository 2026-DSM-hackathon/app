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
                '배터리 ${device.battery}% · ${device.connected ? '연결됨' : '연결 안됨'}',
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
