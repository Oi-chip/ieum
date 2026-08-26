import 'package:flutter_tts/flutter_tts.dart';

class TtsService {

  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _flutterTts = FlutterTts();

  bool _isInitialized = false;
  Future<void>? _initializing;
  int _requestId = 0;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 여러 화면에서 동시에 호출해도 초기화는 한 번만 한다.
    final initializing = _initializing;
    if (initializing != null) return initializing;

    final initialization = _initialize();
    _initializing = initialization;
    try {
      await initialization;
      _isInitialized = true;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize() async {
    await _flutterTts.setLanguage('ko-KR');
    await _selectKoreanMaleVoice();

    await _flutterTts.setVolume(1.0);

    await _flutterTts.setSpeechRate(0.52);

    await _flutterTts.setPitch(0.9);

    await _flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _selectKoreanMaleVoice() async {
    final voices = await _flutterTts.getVoices;
    if (voices is! List) return;

    final koreanVoices = voices
        .whereType<Map>()
        .map(
          (voice) => Map<String, String>.fromEntries(
            voice.entries.map(
              (entry) => MapEntry(entry.key.toString(), entry.value.toString()),
            ),
          ),
        )
        .where(
          (voice) =>
              (voice['locale'] ?? '').toLowerCase().replaceAll('_', '-') ==
              'ko-kr',
        )
        .toList();

    if (koreanVoices.isEmpty) return;

    // 엔진마다 이름이 달라 남성, Google 한국어, 첫 한국어 음성 순으로 고른다.
    final selectedVoice = koreanVoices.firstWhere(
      (voice) {
        final name = (voice['name'] ?? '').toLowerCase();
        return name.contains('male') && !name.contains('female');
      },
      orElse: () => koreanVoices.firstWhere(
        (voice) => (voice['name'] ?? '').toLowerCase().contains('koc'),
        orElse: () => koreanVoices.first,
      ),
    );

    await _flutterTts.setVoice(selectedVoice);
  }

  Future<void> speak(String text) async {
    final String textToSpeak = text.trim();

    if (textToSpeak.isEmpty) {
      return;
    }

    final requestId = ++_requestId;

    await initialize();

    // 초기화 중 새 요청이나 중지 요청이 들어오면 이전 요청은 버린다.
    if (requestId != _requestId) return;

    await _flutterTts.stop();

    if (requestId != _requestId) return;

    await _flutterTts.speak(textToSpeak);
  }

  Future<void> stop() async {
    _requestId++;
    await _flutterTts.stop();
  }
}
