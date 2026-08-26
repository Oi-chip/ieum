import 'dart:async';

import 'package:flutter/material.dart';

import '../services/stt_service.dart';
import '../services/tts_service.dart';

class VoiceButton extends StatefulWidget {
  final ValueChanged<String> onResult;

  const VoiceButton({super.key, required this.onResult});

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton> {
  bool _isListening = false;
  bool _isBusy = false;
  bool _ownsListeningSession = false;
  bool _resultDelivered = false;
  String _recognizedText = '';

  Future<void> _toggleListening() async {
    if (_isBusy) return;

    if (_isListening) {
      setState(() => _isBusy = true);
      await SttService.instance.stopListening();
      if (mounted) setState(() => _isBusy = false);
      return;
    }

    setState(() {
      _isBusy = true;
      _resultDelivered = false;
      _recognizedText = '';
    });

    // 안내 음성이 인식 결과에 섞이지 않게 먼저 멈춘다.
    await TtsService.instance.stop();

    final started = await SttService.instance.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _recognizedText = text);
        if (isFinal && !_resultDelivered) {
          _resultDelivered = true;
          unawaited(_finishWithResult(text));
        }
      },
      onListeningChanged: (isListening) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isListening = isListening;
          _ownsListeningSession = isListening;
          if (isListening) _isBusy = false;
        });

        // final 결과가 없는 기기에서는 마지막 중간 결과를 사용한다.
        if (!isListening && _recognizedText.isNotEmpty && !_resultDelivered) {
          _resultDelivered = true;
          unawaited(_finishWithResult(_recognizedText));
        }
      },
      onError: (message) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        setState(() => _isBusy = false);
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isListening = started;
      _ownsListeningSession = started;
      _isBusy = false;
    });
  }

  Future<void> _finishWithResult(String text) async {
    await SttService.instance.stopListening();
    if (mounted) widget.onResult(text);
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
        onPressed: _isBusy ? null : _toggleListening,
        icon: Icon(
          _isBusy
              ? Icons.hourglass_top
              : _isListening
              ? Icons.stop_circle_outlined
              : Icons.mic,
          size: 34,
        ),
        label: Text(
          _isBusy
              ? '음성 인식 준비 중...'
              : _isListening && _recognizedText.isNotEmpty
              ? _recognizedText
              : _isListening
              ? '듣는 중... 다시 누르면 종료'
              : '눌러서 말하기',
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
