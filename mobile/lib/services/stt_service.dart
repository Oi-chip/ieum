import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef SttResultCallback = void Function(String text, bool isFinal);
typedef SttListeningCallback = void Function(bool isListening);
typedef SttErrorCallback = void Function(String message);

class SttService {
  SttService._();

  static final SttService instance = SttService._();

  final SpeechToText _speech = SpeechToText();

  bool _isAvailable = false;
  Future<bool>? _initializing;
  String? _koreanLocaleId;
  SttResultCallback? _onResult;
  SttListeningCallback? _onListeningChanged;
  SttErrorCallback? _onError;

  bool get isAvailable => _isAvailable;
  bool get isListening => _speech.isListening;

  Future<bool> initialize() async {
    if (_isAvailable) return true;

    final initializing = _initializing;
    if (initializing != null) return initializing;

    final initialization = _initialize();
    _initializing = initialization;
    try {
      return await initialization;
    } finally {
      _initializing = null;
    }
  }

  Future<bool> _initialize() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        // 앱에서 쓰지 않는 블루투스 권한은 요청하지 않는다.
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

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancelListening() async {
    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }
    } finally {
      _onListeningChanged?.call(false);
      _clearCallbacks();
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
    _clearCallbacks();
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
