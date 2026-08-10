# 버스 API 설계

## 가까운 버스정류장 조회

### 요청

- 방식: `GET`
- 주소: `/api/bus/nearby`

### 요청값

| 이름 | 의미 | 필수 |
|---|---|---|
| `latitude` | 현재 위치의 위도 | 필수 |
| `longitude` | 현재 위치의 경도 | 필수 |

### 요청 예시

```text
GET /api/bus/nearby?latitude=36.3&longitude=127.3
```

### 성공 응답 예시

```json
{
  "success": true,
  "data": {
    "stops": [
      {
        "id": "DJB8002012",
        "city_code": "25",
        "name": "성북3통굿개말길",
        "number": "40600",
        "latitude": 36.298546,
        "longitude": 127.29593,
        "distance_m": 206
      }
    ]
  },
  "message": "가까운 버스정류장을 조회했습니다.",
  "source": "국토교통부 TAGO",
  "updated_at": "2026-08-10T08:30:00Z"
}
```

### 실패 응답 예시

```json
{
  "success": false,
  "error": {
    "code": "INVALID_LOCATION",
    "message": "위도와 경도를 올바르게 입력해 주세요."
  }
}
```

### 오류 코드

| 코드 | 의미 | HTTP 상태 |
|---|---|---|
| `MISSING_LOCATION` | 위도 또는 경도가 없음 | 400 |
| `INVALID_LOCATION` | 위도 또는 경도의 형식이나 범위가 잘못됨 | 400 |
| `BUS_API_KEY_MISSING` | 서버에 버스 API 키가 설정되지 않음 | 500 |
| `BUS_DATA_UNAVAILABLE` | 외부 버스 API를 사용할 수 없음 | 502 |
