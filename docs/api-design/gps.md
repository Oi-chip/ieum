# GPS 서비스 사용법

GPS는 서버 API가 아니라 Flutter 앱에서 휴대전화의 현재 위치를 가져오는 기능입니다.

- 서비스: `mobile/lib/services/gps_service.dart`
- 결과 모델: `mobile/lib/models/gps_location.dart`
- 반환 정보: 위도, 경도, 정확도, 측정 시각, 시도, 시군구, 읍면동, 주소
- Android에서는 앱 사용 중 위치 권한만 요청합니다.

## 기본 사용법

```dart
import '../services/gps_service.dart';

try {
  final location = await GpsService.instance.getCurrentLocation();

  print(location.latitude);
  print(location.longitude);
  print(location.displayName);
} on GpsException catch (error) {
  // SnackBar 등으로 error.message를 보여줍니다.
}
```

## 버스 API에 연결

버스 주변 정류장 조회는 위도와 경도만 필요합니다.

```dart
final location = await GpsService.instance.getCurrentLocation();

final uri = Uri.parse('$baseUrl/api/bus/nearby').replace(
  queryParameters: location.toQueryParameters(includeRegion: false),
);
```

전송되는 값:

```text
latitude=36.8936330
longitude=128.7312033
```

## 병원 API에 연결

병원 주변 조회에는 위도·경도와 시도·시군구가 모두 필요합니다.

```dart
final location = await GpsService.instance.getCurrentLocation(
  requireRegion: true,
);

final uri = Uri.parse('$baseUrl/api/hospitals/nearby').replace(
  queryParameters: {
    ...location.toQueryParameters(),
    'radius_m': '20000',
    'limit': '20',
  },
);
```

전송되는 값:

```text
latitude=36.8936330
longitude=128.7312033
sido=경상북도
sigungu=봉화군
```

## 화면에 현재 위치 표시

```dart
Text('현재 위치 : ${location.displayName}')
```

예: `현재 위치 : 경상북도 봉화군 봉화읍`

## 오류 처리

`GpsException.code`로 상황에 맞는 버튼을 보여줄 수 있습니다.

| 오류 코드 | 의미 | 권장 동작 |
|---|---|---|
| `locationServiceDisabled` | 휴대전화 위치 기능이 꺼짐 | `openLocationSettings()` 버튼 표시 |
| `permissionDenied` | 위치 권한 거절 | 기능에 위치가 필요한 이유 안내 후 재시도 |
| `permissionDeniedForever` | 위치 권한 영구 거절 | `openAppSettings()` 버튼 표시 |
| `timeout` | 15초 안에 위치를 찾지 못함 | 야외 이동 또는 GPS 확인 후 재시도 |
| `positionUnavailable` | 좌표를 가져오지 못함 | 잠시 후 재시도 |
| `addressUnavailable` | 시도·시군구 변환 실패 | 병원 조회를 중단하고 재시도 |

설정 화면 열기:

```dart
await GpsService.instance.openLocationSettings();
await GpsService.instance.openAppSettings();
```

## 에뮬레이터 시험

에뮬레이터의 `Extended controls(⋮) → Location`에서 위치를 입력한 뒤 `Set location`을 누릅니다. 봉화읍 시험 좌표는 다음과 같습니다.

```text
latitude: 36.893633
longitude: 128.7312033
```
