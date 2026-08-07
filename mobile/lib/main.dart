import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

// ============================================================
// 이 함수는 이음 앱이 시작될 때 가장 먼저 실행됩니다.
// ============================================================
void main() {
  // MyApp 위젯을 화면에 표시하여 앱을 시작합니다.
  runApp(const MyApp());
}

// ============================================================
// 이 위젯은 이음 앱의 전체 기본 설정을 담당합니다.
// ============================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// 이 함수는 앱의 제목, 테마, 첫 화면을 설정합니다.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 앱의 이름입니다.
      title: '이음',

      // 화면 오른쪽 위에 표시되는 DEBUG 띠를 숨깁니다.
      debugShowCheckedModeBanner: false,

      // 앱 전체에서 사용하는 기본 색상 설정입니다.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

      // 앱을 실행했을 때 가장 먼저 보여 줄 화면입니다.
      home: const HomeScreen(),
    );
  }
}
