import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/app_settings.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final SharedPreferencesAsync preferences =
      SharedPreferencesAsync();
  final int savedFontSize =
      await preferences.getInt('selectedFontSize') ?? 1;
  final int safeFontSize =
      savedFontSize >= 0 && savedFontSize <= 3
          ? savedFontSize
          : 1;
  appFontScale.value =
      appFontScales[safeFontSize];

  runApp(const IeumApp());
}

class IeumApp extends StatelessWidget {
  const IeumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '이음',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF81C784),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
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

      home: const HomeScreen(),
    );
  }
}
