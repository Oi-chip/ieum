import 'dart:async';

import 'package:flutter/material.dart';

import '../services/stt_service.dart';
import '../services/tts_service.dart';

/// 앱에서 공통으로 사용하는 음성 인식 버튼입니다.
///
/// 버튼을 누르면 한국어 음성 인식을 시작하고, 최종 인식 문장을
/// [onResult]로 현재 화면에 전달합니다. 듣는 중 다시 누르면 종료합니다.
class VoiceButton extends StatefulWidget {
  final ValueChanged<String> onResult;

  const VoiceButton({super.key, required this.onResult});

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton> {
  bool _isListening = false;
  bool _ownsListeningSession = false;

  Future<void> _toggleListening() async {
    if (_isListening) {
      await SttService.instance.stopListening();
      return;
    }

    // TTS 음성을 STT가 다시 받아 적지 않도록 먼저 음성 안내를 멈춥니다.
    await TtsService.instance.stop();

    final started = await SttService.instance.startListening(
      onResult: (text, isFinal) {
        if (isFinal && mounted) {
          widget.onResult(text);
        }
      },
      onListeningChanged: (isListening) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isListening = isListening;
          _ownsListeningSession = isListening;
        });
      },
      onError: (message) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isListening = started;
      _ownsListeningSession = started;
    });
  }

  @override
  void dispose() {
    if (_ownsListeningSession) {
      unawaited(SttService.instance.cancelListening());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: ElevatedButton.icon(
        onPressed: _toggleListening,
        icon: Icon(
          _isListening ? Icons.stop_circle_outlined : Icons.mic,
          size: 34,
        ),
        label: Text(
          _isListening ? '듣는 중... 다시 누르면 종료' : '눌러서 말하기',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isListening
              ? const Color(0xFFE57373)
              : const Color(0xFF81C784),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
