// ============================================================
// 이 파일은 앱의 글자를 음성으로 읽어주는 기능을 담당합니다.
//
// 예시:
// "버스 시간표"라는 글자를 이 파일에 전달하면
// 휴대전화가 실제 음성으로 "버스 시간표"라고 읽어줍니다.
//
// 화면 디자인을 만드는 파일은 아니고,
// TTS 기능만 따로 관리하기 위한 파일입니다.
// ============================================================

// flutter_tts 패키지를 사용하기 위해 불러옵니다.
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  // ----------------------------------------------------------
  // TtsService를 앱 전체에서 하나만 사용하기 위한 설정입니다.
  //
  // 초보 단계에서는 아래 구조를 전부 이해하지 않아도 괜찮습니다.
  // 쉽게 말하면:
  // "TTS 기계를 여러 개 만들지 않고 하나만 만들어 같이 사용한다"
  // 라고 생각하면 됩니다.
  // ----------------------------------------------------------

  TtsService._();

  // 앱의 다른 파일에서 아래처럼 사용할 수 있습니다.
  //
  // TtsService.instance.speak('안녕하세요');
  //
  static final TtsService instance = TtsService._();

  // 실제로 글자를 음성으로 바꿔주는 TTS 객체입니다.
  final FlutterTts _flutterTts = FlutterTts();

  // TTS 설정이 이미 끝났는지 확인하는 변수입니다.
  //
  // false = 아직 설정하지 않음
  // true  = 설정 완료
  bool _isInitialized = false;
  Future<void>? _initializing;
  int _requestId = 0;

  // ==========================================================
  // TTS의 기본 설정을 준비하는 함수
  // ==========================================================
  Future<void> initialize() async {
    // 이미 설정이 끝났다면 다시 설정하지 않고 종료합니다.
    if (_isInitialized) return;

    // 여러 화면에서 동시에 처음 호출되어도 초기화는 한 번만 수행합니다.
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
    // 한국어 음성으로 읽도록 설정합니다.
    await _flutterTts.setLanguage('ko-KR');
    await _selectKoreanMaleVoice();

    // 음량을 설정합니다.
    //
    // 0.0 = 소리가 나지 않음
    // 1.0 = 최대 음량
    await _flutterTts.setVolume(1.0);

    // 읽는 속도를 설정합니다.
    //
    // 숫자가 작을수록 천천히 읽습니다.
    // 더 빠르게 들리도록 속도를 높였습니다.
    await _flutterTts.setSpeechRate(0.52);

    // 목소리 높낮이를 설정합니다.
    //
    // 남성 음성이 자연스럽게 들리도록 기본값보다 조금 낮춥니다.
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

    // 엔진마다 음성 이름이 다르므로 남성 표기, Google 한국어 남성 음성,
    // 설치된 첫 한국어 음성 순서로 안전하게 선택합니다.
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

  // ==========================================================
  // 전달받은 글자를 실제 음성으로 읽는 함수
  // ==========================================================
  Future<void> speak(String text) async {
    // 전달받은 글자의 앞뒤 빈칸을 제거합니다.
    //
    // 예:
    // "  안녕하세요  " → "안녕하세요"
    final String textToSpeak = text.trim();

    // 읽을 글자가 비어 있다면 아무것도 하지 않습니다.
    if (textToSpeak.isEmpty) {
      return;
    }

    final requestId = ++_requestId;

    // TTS 설정이 아직 안 되어 있으면 먼저 설정합니다.
    await initialize();

    // 초기화 중 더 최신 읽기/중지 요청이 들어왔으면 이 요청은 버립니다.
    if (requestId != _requestId) return;

    // 이전에 읽고 있던 음성이 있으면 먼저 중지합니다.
    //
    // 예:
    // "버스 시간표"를 읽는 도중
    // "병원 정보"를 누르면 이전 음성을 멈추고 새 글자를 읽습니다.
    await _flutterTts.stop();

    if (requestId != _requestId) return;

    // 전달받은 글자를 음성으로 읽습니다.
    await _flutterTts.speak(textToSpeak);
  }

  // ==========================================================
  // 현재 읽고 있는 음성을 중지하는 함수
  // ==========================================================
  Future<void> stop() async {
    _requestId++;
    await _flutterTts.stop();
  }
}
