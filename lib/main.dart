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

class HackApp extends ConsumerStatefulWidget {
  const HackApp({super.key});

  @override
  ConsumerState<HackApp> createState() => _HackAppState();
}

class _HackAppState extends ConsumerState<HackApp> {
  @override
  void initState() {
    super.initState();
    // 앱 진입 즉시 OS 알림 권한을 요청한다(기기 자체 설정 팝업).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bool granted =
          await ref.read(notificationServiceProvider).requestPermission();
      if (mounted) {
        ref.read(notificationEnabledProvider.notifier).set(granted);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAVIN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const OnboardingScreen(),
    );
  }
}
