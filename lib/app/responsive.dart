import 'package:flutter/material.dart';

/// 기종(화면 크기) 반응형 헬퍼.
///
/// 좁은 화면(폰)에서는 그대로, 넓은 화면(태블릿/폴더블/데스크톱)에서는
/// 콘텐츠를 [maxWidth]로 제한해 가운데 정렬한다.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 600});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// 공용 브레이크포인트.
abstract final class Breakpoints {
  /// 이 폭 이상이면 스탯 카드를 한 줄(4열)로 배치한다.
  static const double wideStats = 520;

  /// 이 폭 미만이면 게이지를 세로로 내려 배치한다(초소형 기기).
  static const double narrowCard = 340;
}
