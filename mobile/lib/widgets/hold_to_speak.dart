import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../services/tts_service.dart';

class HoldToSpeak extends StatefulWidget {
  const HoldToSpeak({super.key, required this.text, required this.child});

  final String text;

  final Widget child;

  @override
  State<HoldToSpeak> createState() => _HoldToSpeakState();
}

class _HoldToSpeakState extends State<HoldToSpeak> {
  void _speak() => TtsService.instance.speak(widget.text);

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
