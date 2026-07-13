import 'package:flutter/material.dart';

import '../../app/app_shell.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../pairing/pairing_screen.dart';

/// 온보딩 인트로(6.2). '시작하기' → 메인 셸, '기기 연결' → 페어링.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 480,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Spacer(),
                Center(
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_moon_rounded,
                        color: AppColors.primary, size: 58),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  '공간 안전 모니터',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                const Text(
                  '레이더·열화상 센서로 차량/공간 내 탑승자를 감지하고,\n고온·장시간 방치를 실시간으로 알려드려요.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const Spacer(),
                const _Feature(
                    icon: Icons.sensors_rounded, label: '실시간 탑승 감지'),
                const _Feature(icon: Icons.thermostat_rounded, label: '고온 경고'),
                const _Feature(
                    icon: Icons.notifications_active_rounded,
                    label: '즉시 알림 · 에스컬레이션'),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const AppShell()),
                  ),
                  child: const Text('시작하기',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const PairingScreen()),
                  ),
                  child: const Text('기기 먼저 연결하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppColors.teal, size: 22),
          const SizedBox(width: 14),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 15)),
        ],
      ),
    );
  }
}
