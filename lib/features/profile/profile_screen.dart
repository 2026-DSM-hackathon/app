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

/// 차종/공간 프로필(6.6, F-08). 사용자 정보·공간 유형·내 기기·설정 진입점을 보여준다.
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
            onEdit: () =>
                _showEditModelDialog(context, ref, profile.modelName),
          ),
          const SizedBox(height: 20),
          _UserCard(profile: profile),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child:
                    _InfoTile(title: '공간 유형', value: profile.spaceType.label),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoTile(title: '차종/모델', value: profile.modelName),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SpaceTypeSelector(profile: profile, ref: ref),
          const SizedBox(height: 26),
          SectionHeader(
            title: '내 기기',
            trailing: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const PairingScreen()),
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

/// '프로필 수정' 다이얼로그: 차종/모델명을 수정해 profileProvider에 반영한다.
Future<void> _showEditModelDialog(
  BuildContext context,
  WidgetRef ref,
  String initialModel,
) async {
  final TextEditingController controller =
      TextEditingController(text: initialModel);
  final String? result = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.stat),
        ),
        title: const Text(
          '프로필 수정',
          style: TextStyle(
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
            labelText: '차종/모델',
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
  if (result != null && result.isNotEmpty) {
    ref.read(profileProvider.notifier).setModelName(result);
  }
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
                  profile.email,
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
class _SpaceTypeSelector extends StatelessWidget {
  const _SpaceTypeSelector({required this.profile, required this.ref});
  final SpaceProfile profile;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
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
                '${device.battery}%',
                style: const TextStyle(
                  color: AppColors.green,
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
