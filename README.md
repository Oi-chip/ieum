# 이음 (ieum)

고령자와 디지털 기기 사용이 익숙하지 않은 사용자가 현재 지역의 버스·병원·날씨 정보를 큰 글씨와 음성으로 쉽게 확인할 수 있는 생활 정보 앱입니다.

복잡한 공공데이터를 여러 사이트에서 찾아야 하는 불편을 줄이고, 긴급 연락과 이동·의료·날씨 정보를 한 화면에서 제공하기 위해 만들었습니다.

## 주요 기능 (Features)

- GPS 현재 위치 또는 시·군·구 직접 선택
- 주변 정류장·도착 정보·노선 상세 및 목적지 직통 버스 검색
- 주변 병원·진료 상태 확인, 이름 검색과 전화 연결
- 기상청 단기예보 조회와 TTS 음성 안내
- STT 음성 명령, 큰 글씨 설정과 지역 설정 저장
- 119 또는 저장한 긴급 연락처로 연결하는 SOS 메뉴

## 설치 방법 (Installation)

### 준비 사항

- Git
- Flutter SDK와 Android SDK
- JDK 17 이상
- Python 3.9 이상
- 공공데이터포털에서 발급받은 디코딩(Decoding) 인증키

Windows PowerShell에서 다음 명령을 실행합니다.

```powershell
git clone https://github.com/Oi-chip/ieum.git
cd ieum

python -m venv server\.venv
.\server\.venv\Scripts\python.exe -m pip install -r server\requirements.txt
Copy-Item server\.env.example server\.env

cd mobile
flutter pub get
cd ..
```

복사한 `server/.env`에 실제 인증키를 입력합니다. 버스·병원·날씨 API가 같은 키를 사용합니다.

```dotenv
data_go_API_KEY=발급받은_디코딩_인증키
```

실제 인증키가 들어 있는 `server/.env`는 Git에 커밋하지 마세요.

## 사용법 (Usage)

첫 번째 PowerShell에서 Flask 서버를 실행합니다.

```powershell
cd ieum
.\server\.venv\Scripts\python.exe server\app.py
```

두 번째 PowerShell에서 Android 에뮬레이터용 Flutter 앱을 실행합니다.

```powershell
cd ieum\mobile
flutter run
```

Android 에뮬레이터는 기본값인 `http://10.0.2.2:5000`으로 개발 PC의 서버에 연결합니다. 실제 Android 기기에서는 PC와 기기를 같은 네트워크에 연결하고 PC의 LAN IP를 지정합니다.

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:5000
```

`192.168.0.10`은 예시이므로 실제 PC의 LAN IP로 바꿔야 합니다. API 요청과 응답 형식은 [`docs/api-design`](docs/api-design)에서 확인할 수 있습니다.

## 프로젝트 구조

```text
ieum/
├─ mobile/
│  ├─ lib/main.dart        # Flutter 진입점
│  ├─ lib/screens/         # 홈, 버스, 병원, 날씨, 설정 화면
│  ├─ lib/services/        # API, GPS, TTS/STT, 설정 저장
│  └─ test/                # Flutter 단위 테스트
├─ server/
│  ├─ app.py               # Flask 진입점
│  ├─ routes/              # 버스, 병원, 날씨 API 라우트
│  ├─ services/            # 공공데이터 API 연동
│  └─ tests/               # Python 단위 테스트
├─ region_data/            # 지역 기준 좌표와 기상 격자 데이터
└─ docs/                   # API 설계와 화면 스케치
```

## 기술 스택

- **모바일:** Dart 3.12+, Flutter, Material 3
- **서버:** Python 3.9+, Flask 3.1.3, Flask-CORS 6.0.5
- **통신:** HTTP, REST API, 공공데이터포털 API
- **위치:** `geolocator`, `geocoding`
- **음성·기기 연동:** `flutter_tts`, `speech_to_text`, `url_launcher`
- **로컬 설정:** `shared_preferences`
- **Android 빌드:** Kotlin, Gradle, JDK 17

앱 버전은 `0.1.0+1`이며 정확한 패키지 버전은 [`mobile/pubspec.yaml`](mobile/pubspec.yaml)과 [`server/requirements.txt`](server/requirements.txt)을 기준으로 합니다.

## 기여 방법 (Contributing)

이슈와 Pull Request를 환영합니다. 변경 전 별도 브랜치를 만들고, 제출 전에 아래 검사를 통과해 주세요.

```powershell
Push-Location server
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
Pop-Location

Push-Location mobile
flutter analyze
flutter test
Pop-Location
```

공공데이터 API를 사용하는 단위 테스트는 모의 응답 기반이므로, 외부 API 연동을 변경했다면 실제 인증키와 네트워크 환경에서도 별도로 확인해 주세요.

## 라이선스

이 프로젝트는 [MIT License](LICENSE)를 따릅니다.
