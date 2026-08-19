import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef SttResultCallback = void Function(String text, bool isFinal);
typedef SttListeningCallback = void Function(bool isListening);
typedef SttErrorCallback = void Function(String message);

/// 휴대전화의 음성 인식 기능을 이용해 한국어 음성을 글자로 바꿉니다.
///
/// [SpeechToText]는 앱에서 하나의 인스턴스만 사용하는 것이 안전하므로
/// [SttService.instance]를 통해 모든 화면이 같은 인스턴스를 공유합니다.
class SttService {
  SttService._();

  static final SttService instance = SttService._();

  final SpeechToText _speech = SpeechToText();

  bool _isAvailable = false;
  String? _koreanLocaleId;
  SttResultCallback? _onResult;
  SttListeningCallback? _onListeningChanged;
  SttErrorCallback? _onError;

  bool get isAvailable => _isAvailable;
  bool get isListening => _speech.isListening;

  /// 음성 인식 가능 여부와 마이크 권한을 확인합니다.
  /// 첫 실행 시 Android가 사용자에게 마이크 권한을 물어볼 수 있습니다.
  Future<bool> initialize() async {
    if (_isAvailable) {
      return true;
    }

    try {
      _isAvailable = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        // 현재 앱은 휴대전화 내장 마이크만 사용하므로 별도의
        // 블루투스 기기 권한을 요청하지 않습니다.
        options: [SpeechToText.androidNoBluetooth],
      );

      if (_isAvailable) {
        _koreanLocaleId ??= await _findKoreanLocaleId();
      }

      return _isAvailable;
    } catch (_) {
      _isAvailable = false;
      return false;
    }
  }

  /// 최대 30초 동안 듣고, 3초간 말이 없으면 자동으로 종료합니다.
  ///
  /// 인식 도중에는 [onResult]가 여러 번 호출될 수 있습니다.
  /// `isFinal`이 true인 결과를 최종 명령으로 사용하면 됩니다.
  Future<bool> startListening({
    required SttResultCallback onResult,
    SttListeningCallback? onListeningChanged,
    SttErrorCallback? onError,
  }) async {
    if (_speech.isListening) {
      await _speech.cancel();
    }

    _onResult = onResult;
    _onListeningChanged = onListeningChanged;
    _onError = onError;

    final available = await initialize();
    if (!available) {
      _onError?.call('음성 인식을 사용할 수 없습니다. 마이크 권한을 확인해 주세요.');
      _onListeningChanged?.call(false);
      return false;
    }

    try {
      await _speech.listen(
        onResult: _handleResult,
        listenOptions: SpeechListenOptions(
          localeId: _koreanLocaleId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
      );

      final started = _speech.isListening;
      _onListeningChanged?.call(started);
      if (!started) {
        _onError?.call('음성 인식을 시작하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
      return started;
    } catch (_) {
      _onListeningChanged?.call(false);
      _onError?.call('음성 인식을 시작하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      return false;
    }
  }

  /// 듣기를 정상 종료하고 마지막 인식 결과를 기다립니다.
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// 현재 인식 결과를 버리고 듣기를 취소합니다.
  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.trim();
    if (text.isNotEmpty) {
      _onResult?.call(text, result.finalResult);
    }
  }

  void _handleStatus(String status) {
    _onListeningChanged?.call(status == SpeechToText.listeningStatus);

    if (status == SpeechToText.doneStatus) {
      _clearCallbacks();
    }
  }

  void _handleError(SpeechRecognitionError error) {
    _onListeningChanged?.call(false);
    _onError?.call(_messageForError(error.errorMsg));

    if (error.permanent) {
      _clearCallbacks();
    }
  }

  void _clearCallbacks() {
    _onResult = null;
    _onListeningChanged = null;
    _onError = null;
  }

  Future<String?> _findKoreanLocaleId() async {
    try {
      final locales = await _speech.locales();
      for (final locale in locales) {
        final normalized = locale.localeId.toLowerCase().replaceAll('_', '-');
        if (normalized == 'ko-kr' || normalized == 'ko') {
          return locale.localeId;
        }
      }
    } catch (_) {
      // 한국어 목록을 가져오지 못하면 휴대전화의 기본 언어를 사용합니다.
    }
    return null;
  }

  String _messageForError(String errorCode) {
    switch (errorCode) {
      case 'error_permission':
      case 'error_permission_denied':
        return '마이크 권한이 필요합니다. 휴대전화 설정에서 권한을 허용해 주세요.';
      case 'error_no_match':
        return '말을 알아듣지 못했습니다. 다시 천천히 말해 주세요.';
      case 'error_network':
      case 'error_network_timeout':
        return '음성 인식에 필요한 인터넷 연결을 확인해 주세요.';
      case 'error_busy':
        return '음성 인식기가 사용 중입니다. 잠시 후 다시 시도해 주세요.';
      case 'error_speech_timeout':
        return '음성이 들리지 않았습니다. 버튼을 누르고 다시 말해 주세요.';
      default:
        return '음성 인식 중 문제가 발생했습니다. 다시 시도해 주세요.';
    }
  }
}
