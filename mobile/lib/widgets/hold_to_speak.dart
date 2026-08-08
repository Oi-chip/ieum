import 'dart:async';

import 'package:flutter/material.dart';

import '../services/tts_service.dart';

// ============================================================
// 자식 위젯을 1초 동안 길게 누르면
// 전달받은 글자를 음성으로 읽어 주는 위젯입니다.
// ============================================================
class HoldToSpeak extends StatefulWidget {
  const HoldToSpeak({
    super.key,
    required this.text,
    required this.child,
  });

  // TTS가 음성으로 읽을 글자입니다.
  final String text;

  // 화면에 표시할 글자, 버튼, 카드 등의 위젯입니다.
  final Widget child;

  /// 이 함수는 길게 누르기 상태를 관리할 객체를 만듭니다.
  @override
  State<HoldToSpeak> createState() => _HoldToSpeakState();
}

class _HoldToSpeakState extends State<HoldToSpeak> {
  // 사용자가 누르기 시작했을 때 실행되는 1초 타이머입니다.
  Timer? holdTimer;

  // 사용자가 현재 화면을 누르고 있는지 저장합니다.
  bool isHolding = false;

  /// 이 함수는 사용자가 위젯을 누르기 시작했을 때 실행됩니다.
  /// 1초 타이머를 시작하고, 계속 누르고 있으면 글자를 읽습니다.
  void _startHolding(PointerDownEvent pointerDownEvent) {
    // 혹시 남아 있는 이전 타이머가 있다면 먼저 취소합니다.
    holdTimer?.cancel();

    isHolding = true;

    holdTimer = Timer(const Duration(seconds: 1), () {
      // 1초가 지나기 전에 손을 뗐다면 읽지 않습니다.
      if (!isHolding) {
        return;
      }

      TtsService.instance.speak(widget.text);
    });
  }

  /// 이 함수는 사용자가 손을 떼거나 누르기가 취소될 때 실행됩니다.
  /// 아직 1초가 지나지 않았다면 음성이 나오지 않도록 타이머를 취소합니다.
  void _stopHolding(PointerEvent pointerEvent) {
    isHolding = false;
    holdTimer?.cancel();
    holdTimer = null;
  }

  /// 이 함수는 위젯이 화면에서 사라질 때 실행됩니다.
  /// 사용하지 않는 타이머가 남지 않도록 안전하게 정리합니다.
  @override
  void dispose() {
    isHolding = false;
    holdTimer?.cancel();
    super.dispose();
  }

  /// 이 함수는 화면에 자식 위젯을 표시하고
  /// 누르기 시작, 손 떼기, 누르기 취소 동작을 감지합니다.
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _startHolding,
      onPointerUp: _stopHolding,
      onPointerCancel: _stopHolding,
      child: widget.child,
    );
  }
}
