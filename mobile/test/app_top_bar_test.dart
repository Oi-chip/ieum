import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/app_top_bar.dart';

void main() {
  testWidgets('뒤로가기 버튼을 표시하고 누르면 콜백을 실행한다', (tester) async {
    var backPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: AppTopBar(
              title: '병원',
              onBackTap: () => backPressed = true,
              onSosTap: () {},
              onSettingsTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackButton), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(BackButton));
    expect(backPressed, isTrue);
  });
}
