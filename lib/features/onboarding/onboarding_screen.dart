import 'package:flutter/material.dart';

import '../../app/app_shell.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../widgets/savin_logo.dart';
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
                // 브랜드 로고(assets/img.png — SAVIN 워드마크 + 금색 삼각형).
                const Center(child: SavinLogo(height: 100)),
                const SizedBox(height: 24),
                const Text(
                  '차량/공간 내 탑승자를 감지해 장시간 방치로 인한\n열사병 및 사고를 방지합니다.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
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
