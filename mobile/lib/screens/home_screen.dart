import 'package:flutter/material.dart';

import '../services/tts_service.dart';
import '../widgets/hold_to_speak.dart';
import 'settings_screen.dart';
import 'weather_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이음'),
      ),

      // ============================================================
      // 화면 가운데에 TTS를 테스할 글자를 배치합니다.
      // ============================================================
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HoldToSpeak로 감싼 영역을
            // 1초 동안 계속 누르면 음성을 읽습니다.
            HoldToSpeak(
              // TTS가 실제로 읽을 문장입니다.
              text: '홈 화면 준비 중',

              // 화면에 보이는 글자
              child: const Text(
                '홈 화면 (준비 중)',
                style: TextStyle(
                  // 글자를 크게 만들어
                  // 테스트하기 쉽게 합니다.
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const WeatherScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.wb_sunny_outlined),
              label: const Text('날씨 보기'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.settings_outlined),
              label: const Text('설정'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await TtsService.instance.speak('이음 앱 테스트입니다.');
              },
              child: const Text('TTS 테스트'),
            ),
          ],
        ),
      ),
    );
  }
}
