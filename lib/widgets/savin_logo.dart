import 'package:flutter/material.dart';

/// SAVIN 브랜드 로고(assets/img.png).
///
/// 다크 배경용 화이트 워드마크 + 금색 삼각형 이미지. 원본이 어두운 배경이라
/// 앱 배경(AppColors.background)과 자연스럽게 어우러진다.
class SavinLogo extends StatelessWidget {
  const SavinLogo({super.key, this.height = 56});

  /// 로고 높이(px). 가로는 원본 비율(약 1.92:1)에 맞춰 자동 결정된다.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/img.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
