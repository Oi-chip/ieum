import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 앱을 세로 화면으로 고정
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const IeumApp());
}

class IeumApp extends StatelessWidget {
  const IeumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 오른쪽 위 DEBUG 표시 제거
      debugShowCheckedModeBanner: false,

      // 앱 이름
      title: '이음',

      // 앱 전체 기본 디자인
      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
        ),

        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),

      // 앱 실행 시 가장 먼저 보여줄 화면
      home: const HomeScreen(),
    );
  }
}