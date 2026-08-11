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

## 정류장별 버스 도착정보 조회

### 요청

- 방식: `GET`
- 주소: `/api/bus/arrivals`

### 요청값

| 이름 | 의미 | 필수 |
|---|---|---|
| `city_code` | 가까운 정류장 조회에서 받은 도시 코드 | 필수 |
| `stop_id` | 가까운 정류장 조회에서 받은 정류장 ID | 필수 |

### 요청 예시

```text
GET /api/bus/arrivals?city_code=25&stop_id=DJB8001793
```

### 성공 응답 예시

```json
{
  "success": true,
  "data": {
    "city_code": "25",
    "stop_id": "DJB8001793",
    "arrivals": [
      {
        "route_id": "DJB30300002",
        "bus_number": "5",
        "route_type": "마을버스",
        "remaining_stops": 3,
        "arrival_seconds": 125,
        "arrival_minutes": 3,
        "vehicle_type": "저상버스"
      }
    ]
  },
  "message": "버스 도착정보를 조회했습니다.",
  "source": "국토교통부 TAGO",
  "updated_at": "2026-08-10T08:30:00Z"
}
```

`arrival_minutes`는 초 단위 도착예정시간을 올림한 값입니다. 예를 들어 125초는 3분으로 표시합니다.
운행 중인 버스가 없거나 해당 지역이 실시간 도착정보를 제공하지 않으면 `arrivals`가 빈 목록일 수 있습니다.

### 오류 코드

| 코드 | 의미 | HTTP 상태 |
|---|---|---|
| `MISSING_STOP` | 도시 코드 또는 정류장 ID가 없음 | 400 |
| `INVALID_STOP` | 도시 코드 또는 정류장 ID 형식이 잘못됨 | 400 |
| `BUS_API_KEY_MISSING` | 서버에 버스 API 키가 설정되지 않음 | 500 |
| `BUS_DATA_UNAVAILABLE` | 외부 도착정보 API를 사용할 수 없음 | 502 |

## 버스 노선 상세정보 조회

### 요청

- 방식: `GET`
- 주소: `/api/bus/route`

### 요청값

| 이름 | 의미 | 필수 |
|---|---|---|
| `city_code` | 도착정보에서 사용한 도시 코드 | 필수 |
| `route_id` | 도착정보에서 받은 노선 ID | 필수 |

### 요청 예시

```text
GET /api/bus/route?city_code=25&route_id=DJB30300002
```

### 성공 응답 예시

```json
{
  "success": true,
  "data": {
    "city_code": "25",
    "route": {
      "id": "DJB30300002",
      "number": "2",
      "type": "급행버스",
      "start_stop": "봉산동",
      "end_stop": "대전역동광장",
      "first_bus_time": "05:45",
      "last_bus_time": "22:30",
      "weekday_interval_minutes": 12,
      "saturday_interval_minutes": 12,
      "sunday_interval_minutes": 16,
      "stops": [
        {
          "id": "DJB8001783",
          "name": "봉산동기점",
          "number": "44490",
          "order": 1,
          "latitude": 36.448254,
          "longitude": 127.384605,
          "direction_code": "0"
        }
      ]
    }
  },
  "message": "버스 노선정보를 조회했습니다.",
  "source": "국토교통부 TAGO",
  "updated_at": "2026-08-10T08:30:00Z"
}
```

첫차·막차 시간이나 배차간격을 외부 API가 제공하지 않으면 해당 값은 `null`입니다.
`stops`는 노선 운행 순서대로 정렬됩니다.

### 오류 코드

| 코드 | 의미 | HTTP 상태 |
|---|---|---|
| `MISSING_ROUTE` | 도시 코드 또는 노선 ID가 없음 | 400 |
| `INVALID_ROUTE` | 도시 코드 또는 노선 ID 형식이 잘못됨 | 400 |
| `BUS_ROUTE_NOT_FOUND` | 해당 노선을 찾을 수 없음 | 404 |
| `BUS_API_KEY_MISSING` | 서버에 버스 API 키가 설정되지 않음 | 500 |
| `BUS_DATA_UNAVAILABLE` | 외부 노선정보 API를 사용할 수 없음 | 502 |

## 정류장별 경유 버스 목록 조회

### 요청

- 방식: `GET`
- 주소: `/api/bus/stop-routes`

### 요청값

| 이름 | 의미 | 필수 |
|---|---|---|
| `city_code` | 가까운 정류장 조회에서 받은 도시 코드 | 필수 |
| `stop_id` | 가까운 정류장 조회에서 받은 정류장 ID | 필수 |

### 요청 예시

```text
GET /api/bus/stop-routes?city_code=37410&stop_id=TSB371000038
```

### 성공 응답 예시

```json
{
  "success": true,
  "data": {
    "city_code": "37410",
    "stop_id": "TSB371000038",
    "routes": [
      {
        "route_id": "TSB371000047",
        "bus_number": "34",
        "route_type": "농어촌(일반)버스",
        "start_stop": "봉화공용터미널",
        "end_stop": "봉화공용터미널"
      }
    ]
  },
  "message": "정류장을 지나는 버스 목록을 조회했습니다.",
  "source": "국토교통부 TAGO",
  "updated_at": "2026-08-10T08:30:00Z"
}
```

정류장을 지나는 노선이 없거나 해당 지역에서 데이터를 제공하지 않으면 `routes`가 빈 목록일 수 있습니다.
목록에서 받은 `route_id`와 `city_code`로 `/api/bus/route`를 호출하면 노선 상세정보를 조회할 수 있습니다.

### 오류 코드

| 코드 | 의미 | HTTP 상태 |
|---|---|---|
| `MISSING_STOP` | 도시 코드 또는 정류장 ID가 없음 | 400 |
| `INVALID_STOP` | 도시 코드 또는 정류장 ID 형식이 잘못됨 | 400 |
| `BUS_API_KEY_MISSING` | 서버에 버스 API 키가 설정되지 않음 | 500 |
| `BUS_DATA_UNAVAILABLE` | 외부 경유노선 API를 사용할 수 없음 | 502 |
