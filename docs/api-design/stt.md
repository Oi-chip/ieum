# STT(음성 인식) 사용법

STT는 서버 API가 아니라 휴대전화의 음성 인식 기능을 사용하는 Flutter 서비스입니다.

- 서비스 파일: `mobile/lib/services/stt_service.dart`
- 사용 패키지: `speech_to_text`
- 기본 언어: 한국어
- 최대 인식 시간: 30초
- 말이 없는 시간이 3초가 되면 자동 종료

## 화면에서 사용하기

현재 공통 `VoiceButton`에 STT가 연결되어 있으므로 화면에서는 최종 문장을
처리할 함수만 전달하면 됩니다.

```dart
VoiceButton(
  onResult: (text) {
    // text에 사용자가 말한 최종 문장이 들어옵니다.
  },
)
```

### 현재 연결된 음성 명령

- 홈: `SOS`/`에스오에스`/`긴급`, `설정`, `버스`, `병원`, `날씨`

홈에서 명령을 인식하면 해당 화면이나 메뉴를 열고 TTS로 이동 내용을 안내합니다.
- 버스 목록: 버스 번호(예: `34번 버스`), 목적지 이름, `새로고침`, `홈으로`
- 버스 상세: 다른 버스 번호(예: `25번 버스`), `즐겨찾기 추가`, `즐겨찾기 해제`, `목록으로`
- 병원 목록: 병원 이름, `가까운 병원`, `홈으로` (한 곳이면 상세로 바로 이동)
- 병원 상세: 다른 병원 이름, `전화`, `목록으로`

## 서비스를 직접 사용할 때

```dart
import '../services/stt_service.dart';

await SttService.instance.startListening(
  onResult: (text, isFinal) {
    if (isFinal) {
      // text에 최종 인식 문장이 들어옵니다.
      // 예: "가까운 병원 알려줘"
    }
  },
  onListeningChanged: (isListening) {
    // true이면 듣는 중, false이면 종료된 상태입니다.
  },
  onError: (message) {
    // SnackBar 등으로 message를 사용자에게 보여줍니다.
  },
);
```

듣기를 직접 끝낼 때는 다음을 사용합니다.

```dart
await SttService.instance.stopListening();
```

현재 결과를 버리고 취소할 때는 다음을 사용합니다.

```dart
await SttService.instance.cancelListening();
```

## 주의 사항

- 처음 사용할 때 Android의 마이크 권한 요청을 허용해야 합니다.
- 실제 기기에 한국어 음성 인식 서비스가 설치되어 있어야 합니다.
- 일부 기기는 음성 인식 과정에서 인터넷 연결이 필요합니다.
- TTS가 재생 중이라면 먼저 TTS를 멈춘 다음 STT를 시작해야 자기 음성을 다시 인식하는 문제를 피할 수 있습니다.
- 화면 이동이나 화면 종료 시 듣는 중이라면 `cancelListening()`을 호출하는 것이 안전합니다.
