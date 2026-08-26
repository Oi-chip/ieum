import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/app_top_bar.dart';

void main() {
  testWidgets('뒤로가기 버튼을 표시하고 누르면 콜백을 실행한다', (tester) async {
    var backPressed = false;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    expect(find.text('SOS'), findsNothing);
    expect(tester.takeException(), isNull);

    final backCenter = tester.getCenter(find.byType(BackButton));
    final titleCenter = tester.getCenter(find.text('병원'));
    final settingsCenter = tester.getCenter(find.text('설정'));
    final topBarCenter = tester.getCenter(find.byType(AppTopBar));

    expect(backCenter.dx, lessThan(titleCenter.dx));
    expect(titleCenter.dx, closeTo(topBarCenter.dx, 1));
    expect(settingsCenter.dx, greaterThan(titleCenter.dx));

    await tester.tap(find.byType(BackButton));
    expect(backPressed, isTrue);
  });

  testWidgets('홈 상단바에는 SOS 버튼을 유지한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTopBar(title: '이음', onSosTap: () {}, onSettingsTap: () {}),
        ),
      ),
    );

    expect(find.text('SOS'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
