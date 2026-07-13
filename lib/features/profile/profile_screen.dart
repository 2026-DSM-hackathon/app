import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../pairing/pairing_screen.dart';
import '../settings/settings_screen.dart';

/// 차종/공간 프로필(6.6, F-08).
/// 차량(제조사)과 차종 모델로 구분해 선택하고, 비차량 모드도 지원한다.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SpaceProfile profile = ref.watch(profileProvider);
    final List<DeviceInfo> devices = ref.watch(devicesProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: <Widget>[
          _Header(
            onEdit: () async {
              final String? name = await _showTextEditDialog(
                context,
                title: '프로필 수정',
                label: '이름',
                initial: profile.userName,
              );
              if (name != null && name.isNotEmpty) {
                ref.read(profileProvider.notifier).setUserName(name);
              }
            },
          ),
          const SizedBox(height: 20),
          _UserCard(profile: profile),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _InfoTile(
                  title: profile.isVehicleMode ? '차량(제조사)' : '공간 유형',
                  value: profile.isVehicleMode
                      ? profile.manufacturer
                      : profile.spaceType.label,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoTile(
                  title: profile.isVehicleMode ? '차종 모델' : '공간 이름',
                  value: profile.modelName,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SpaceTypeSelector(profile: profile),
          const SizedBox(height: 16),
          if (profile.isVehicleMode)
            _VehicleModelCard(profile: profile)
          else
            _SpaceNameCard(profile: profile),
          const SizedBox(height: 26),
          SectionHeader(
            title: '내 기기',
            trailing: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PairingScreen()),
              ),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (devices.isEmpty)
            const AppCard(
              child: Text(
                '등록된 기기가 없어요. + 버튼으로 추가하세요.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            )
          else
            for (int i = 0; i < devices.length; i++) ...<Widget>[
              _DeviceTile(device: devices[i]),
              if (i != devices.length - 1) const SizedBox(height: 10),
            ],
          const SizedBox(height: 26),
          const SectionHeader(title: '추가'),
          const SizedBox(height: 12),
          _AdditionalCard(
            onSettingsTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// 공용 텍스트 수정 다이얼로그(이름/차종 모델/공간 이름).
Future<String?> _showTextEditDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String initial,
}) async {
  final TextEditingController controller = TextEditingController(text: initial);
  final String? result = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.stat),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: AppColors.textSecondary),
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
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              '취소',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text(
              '저장',
              style: TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

class _Header extends StatelessWidget {
  const _Header({required this.onEdit});
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        const Text(
          '프로필',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.edit, size: 15, color: Colors.black),
                SizedBox(width: 6),
                Text(
                  '프로필 수정',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.profile});
  final SpaceProfile profile;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.surfaceAlt,
            child: Text(
              _initials(profile.userName),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile.userName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  // 로그인 미사용: 이메일 대신 상태 문구를 보여준다.
                  profile.email.isEmpty ? '로그인 없이 사용 중' : profile.email,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final List<String> parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 공간 유형 선택 칩(비차량 모드 포함, 6.6).
class _SpaceTypeSelector extends ConsumerWidget {
  const _SpaceTypeSelector({required this.profile});
  final SpaceProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '공간 유형 선택',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final SpaceType type in SpaceType.values)
                ChoiceChip(
                  label: Text(type.label),
                  selected: profile.spaceType == type,
                  showCheckmark: false,
                  onSelected: (_) =>
                      ref.read(profileProvider.notifier).setSpaceType(type),
                  backgroundColor: AppColors.surfaceAlt,
                  selectedColor: AppColors.primary,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  labelStyle: TextStyle(
                    color: profile.spaceType == type
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
            ],
          ),
          if (!profile.isVehicleMode) ...<Widget>[
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '비차량 모드로 동작 중이에요 · 온도/탑승 감지 기준이 조정돼요',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 차량 모드: 제조사(차량) → 차종 모델 2단 선택 + 직접 입력.
class _VehicleModelCard extends ConsumerWidget {
  const _VehicleModelCard({required this.profile});
  final SpaceProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> manufacturers = <String>[
      ...kVehicleCatalog.keys,
      kCustomManufacturer,
    ];
    final bool isCatalog = profile.isCatalogManufacturer;
    final String manufacturerValue =
        isCatalog ? profile.manufacturer : kCustomManufacturer;
    final List<String> models =
        isCatalog ? kVehicleCatalog[profile.manufacturer]! : const <String>[];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '차량 · 차종 모델',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _DropdownField(
            label: '차량(제조사)',
            value: manufacturerValue,
            items: manufacturers,
            onChanged: (String? v) {
              if (v == null) return;
              ref.read(profileProvider.notifier).setManufacturer(v);
            },
          ),
          const SizedBox(height: 12),
          if (isCatalog)
            _DropdownField(
              label: '차종 모델',
              value: models.contains(profile.modelName)
                  ? profile.modelName
                  : null,
              items: models,
              onChanged: (String? v) {
                if (v == null) return;
                ref.read(profileProvider.notifier).setModelName(v);
              },
            )
          else
            _EditableValueRow(
              label: '차종 모델(직접 입력)',
              value: profile.modelName,
              onEdit: () async {
                final String? model = await _showTextEditDialog(
                  context,
                  title: '차종 모델 입력',
                  label: '차종 모델',
                  initial: profile.modelName,
                );
                if (model != null && model.isNotEmpty) {
                  ref.read(profileProvider.notifier).setModelName(model);
                }
              },
            ),
        ],
      ),
    );
  }
}

/// 비차량 모드: 공간 이름 직접 입력.
class _SpaceNameCard extends ConsumerWidget {
  const _SpaceNameCard({required this.profile});
  final SpaceProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '공간 정보',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _EditableValueRow(
            label: '공간 이름',
            value: profile.modelName,
            onEdit: () async {
              final String? name = await _showTextEditDialog(
                context,
                title: '공간 이름 입력',
                label: '공간 이름',
                initial: profile.modelName,
              );
              if (name != null && name.isNotEmpty) {
                ref.read(profileProvider.notifier).setModelName(name);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// 라벨 + 다크 드롭다운 필드.
class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: const Text(
                '선택',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              ),
              dropdownColor: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.expand_more,
                  color: AppColors.textSecondary),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              items: <DropdownMenuItem<String>>[
                for (final String item in items)
                  DropdownMenuItem<String>(value: item, child: Text(item)),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// 라벨 + 현재 값 + 수정 버튼(직접 입력용).
class _EditableValueRow extends StatelessWidget {
  const _EditableValueRow({
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final String label;
  final String value;
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
                value.isEmpty ? '—' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onEdit,
          tooltip: '수정',
          icon: const Icon(Icons.edit_outlined,
              color: AppColors.textSecondary, size: 20),
        ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});
  final DeviceInfo device;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceAlt,
            child: Icon(
              Icons.bluetooth,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  device.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  device.sensorType.label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                device.hasBattery ? '${device.battery}%' : '—',
                style: TextStyle(
                  color: device.hasBattery
                      ? AppColors.green
                      : AppColors.textTertiary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              StatusPill(
                label: device.connected ? '연결됨' : '연결 안 됨',
                color: device.connected
                    ? AppColors.green
                    : AppColors.textTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdditionalCard extends StatelessWidget {
  const _AdditionalCard({required this.onSettingsTap});
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _AdditionalTile(
              icon: Icons.star,
              label: '프리미엄 전환',
              onTap: () => _showComingSoon(context),
            ),
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.divider,
              indent: 16,
              endIndent: 16,
            ),
            _AdditionalTile(
              icon: Icons.shield,
              label: '안전 정보',
              onTap: () => _showComingSoon(context),
            ),
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.divider,
              indent: 16,
              endIndent: 16,
            ),
            _AdditionalTile(
              icon: Icons.settings,
              label: '설정',
              onTap: onSettingsTap,
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('준비 중')),
    );
  }
}

class _AdditionalTile extends StatelessWidget {
  const _AdditionalTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textTertiary,
      ),
    );
  }
}
