import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/app_settings.dart';
import 'screens/home_screen.dart';

// ============================================================
// 이 함수는 이음 앱이 시작될 때 가장 먼저 실행됩니다.
// ============================================================
Future<void> main() async {
  // 앱 실행 전에 저장된 설정을 읽기 위해 필요합니다.
  WidgetsFlutterBinding.ensureInitialized();

  // 앱을 세로 화면으로 고정합니다.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final SharedPreferencesAsync preferences =
      SharedPreferencesAsync();
  // 이전에 저장한 글씨 크기 단계를 불러옵니다.
  final int savedFontSize =
      await preferences.getInt('selectedFontSize') ?? 1;
  // 저장된 값이 0~3 범위를 벗어나면 기본값을 사용합니다.
  final int safeFontSize =
      savedFontSize >= 0 && savedFontSize <= 3
          ? savedFontSize
          : 1;
  // 저장된 글씨 크기를 앱 전체 설정값에 반영합니다.
  appFontScale.value =
      appFontScales[safeFontSize];

  // IeumApp 위젯을 화면에 표시하여 앱을 시작합니다.
  runApp(const IeumApp());
}

// ============================================================
// 이 위젯은 이음 앱의 전체 기본 설정을 담당합니다.
// ============================================================
class IeumApp extends StatelessWidget {
  const IeumApp({super.key});

  /// 이 함수는 앱의 제목, 테마, 첫 화면을 설정합니다.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 화면 오른쪽 위에 표시되는 DEBUG 띠를 숨깁니다.
      debugShowCheckedModeBanner: false,
      // 앱의 이름입니다.
      title: '이음',
      // 앱 전체에서 사용하는 기본 색상 및 배경 설정입니다.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF81C784),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      // 설정에서 선택한 글씨 크기를 앱 전체 화면에 적용합니다.
      builder: (context, child) {
        return ValueListenableBuilder<double>(
          valueListenable: appFontScale,
          builder: (context, fontScale, _) {
            final MediaQueryData mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(
                  fontScale,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },

      // 앱을 실행했을 때 가장 먼저 보여 줄 화면입니다.
      home: const HomeScreen(),
    );
  }
}