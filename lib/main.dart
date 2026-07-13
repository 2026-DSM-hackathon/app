import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/theme.dart';
import 'core/providers.dart';
import 'core/services/local_notification_service.dart';
import 'features/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 로컬 알림(열사병 경보)은 기기 자체에서 발송 — 초기화 후 주입한다.
  final LocalNotificationService notifications = LocalNotificationService();
  await notifications.init();

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWith((ref) => notifications),
      ],
      child: const HackApp(),
    ),
  );
}

class HackApp extends StatelessWidget {
  const HackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '공간 안전 모니터',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const OnboardingScreen(),
    );
  }
}
