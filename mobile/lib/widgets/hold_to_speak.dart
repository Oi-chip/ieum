import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../services/tts_service.dart';

// ============================================================
// 자식 위젯을 1초 동안 길게 누르면
// 전달받은 글자를 음성으로 읽어 주는 위젯입니다.
// ============================================================
class HoldToSpeak extends StatefulWidget {
  const HoldToSpeak({super.key, required this.text, required this.child});

  // TTS가 음성으로 읽을 글자입니다.
  final String text;

  // 화면에 표시할 글자, 버튼, 카드 등의 위젯입니다.
  final Widget child;

  /// 이 함수는 길게 누르기 상태를 관리할 객체를 만듭니다.
  @override
  State<HoldToSpeak> createState() => _HoldToSpeakState();
}

class _HoldToSpeakState extends State<HoldToSpeak> {
  void _speak() => TtsService.instance.speak(widget.text);

  /// 이 함수는 화면에 자식 위젯을 표시하고
  /// 누르기 시작, 손 떼기, 누르기 취소 동작을 감지합니다.
  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: '내용 음성으로 듣기'): _speak,
      },
      child: RawGestureDetector(
        gestures: {
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: const Duration(seconds: 1),
                ),
                (recognizer) => recognizer.onLongPress = _speak,
              ),
        },
        behavior: HitTestBehavior.opaque,
        child: widget.child,
      ),
    );
  }
}
