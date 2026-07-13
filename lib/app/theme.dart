import 'package:flutter/material.dart';

import '../core/models.dart';

/// 앱 전역 색상 토큰. 참조 디자인(다크 대시보드)에서 추출한 값.
abstract final class AppColors {
  // 배경 계층
  static const Color background = Color(0xFF0F1216);
  static const Color surface = Color(0xFF1B1F27); // 카드
  static const Color surfaceAlt = Color(0xFF232833); // 카드 내부 칩/스탯
  static const Color divider = Color(0xFF2A2F3A);

  // 강조
  static const Color primary = Color(0xFF7C5CFC); // 보라 (FAB/활성)
  static const Color green = Color(0xFF83E04A); // 게이지/정상
  static const Color teal = Color(0xFF2FD3C3); // 차트 라인 1
  static const Color blue = Color(0xFF5B8DEF); // 차트 라인 2
  static const Color orange = Color(0xFFF59E3C); // 경고/초과
  static const Color red = Color(0xFFFF5A5F); // 위험

  // 텍스트
  static const Color textPrimary = Color(0xFFF5F6F8);
  static const Color textSecondary = Color(0xFF9AA0AE);
  static const Color textTertiary = Color(0xFF5E6472);
}

/// 앱 테마(다크 전용). 참조 디자인의 카드/타이포/배경을 반영.
abstract final class AppTheme {
  static ThemeData get dark {
    const ColorScheme scheme = ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.teal,
      surface: AppColors.surface,
      error: AppColors.red,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    );

    const TextTheme text = TextTheme(
      headlineMedium:
          TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      titleLarge:
          TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      titleMedium:
          TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodySmall: TextStyle(color: AppColors.textSecondary),
      labelMedium: TextStyle(color: AppColors.textSecondary),
      labelSmall: TextStyle(color: AppColors.textSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      textTheme: text,
      cardColor: AppColors.surface,
      dividerColor: AppColors.divider,
      splashColor: AppColors.primary.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// 공용 반경/여백 상수.
abstract final class AppRadii {
  static const double card = 22;
  static const double stat = 16;
  static const double pill = 999;
}

/// CO2 공기질 등급 → 색상(위젯/차트 공용).
extension AirQualityColor on AirQuality {
  Color get color => switch (this) {
        AirQuality.good => AppColors.green,
        AirQuality.moderate => AppColors.orange,
        AirQuality.poor => AppColors.red,
      };
}

/// 열사병 확률(0.0~1.0) → 위험도 색상(게이지/위젯 공용).
Color heatstrokeColor(double risk) => risk >= 0.7
    ? AppColors.red
    : (risk >= 0.4 ? AppColors.orange : AppColors.green);
