// 로그인 화면이 렌더링되는지 확인하는 스모크 테스트.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:report_admin_app/pages/login_page.dart';

void main() {
  testWidgets('로그인 화면 렌더링', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    expect(find.text('관리자 로그인'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
  });
}
