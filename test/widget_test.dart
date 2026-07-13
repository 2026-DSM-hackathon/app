// 홈 화면 위젯 스모크 테스트.
//
// 알림 섹션(차량 온도/사람 감지)과 차량 기종 선택 섹션이
// 올바르게 렌더링되는지 검증한다.

import 'package:flutter_test/flutter_test.dart';

import 'package:hack_app/main.dart';

void main() {
  testWidgets('홈 화면에 알림 및 차량 기종 선택 섹션이 표시된다',
      (WidgetTester tester) async {
    await tester.pumpWidget(const HackApp());

    // 섹션 제목
    expect(find.text('알림'), findsOneWidget);
    expect(find.text('차량 기종 선택'), findsOneWidget);

    // 알림 하위 카드
    expect(find.text('차량 온도'), findsOneWidget);
    expect(find.text('사람 감지'), findsOneWidget);

    // 기본 선택된 차량 기종
    expect(find.text('현대 아이오닉 5'), findsOneWidget);
  });
}
