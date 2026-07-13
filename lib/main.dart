import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/theme.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() {
  runApp(const ProviderScope(child: HackApp()));
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
