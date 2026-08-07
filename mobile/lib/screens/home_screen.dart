import 'package:flutter/material.dart';

import '../widgets/hold_to_speak.dart';

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
        // HoldToSpeak로 감싼 영역을
        // 1초 동안 계속 누르면 음성을 읽습니다.
        child: HoldToSpeak(
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
      ),
    );
  }
}
