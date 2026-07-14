// 온보딩 진입 화면 스모크 테스트.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hack_app/main.dart';
import 'package:hack_app/widgets/savin_logo.dart';

void main() {
  testWidgets('앱 시작 시 온보딩 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HackApp()));

    expect(find.byType(SavinLogo), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });
}
