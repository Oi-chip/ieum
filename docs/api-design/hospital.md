# 병원 API 설계

사용 데이터: [국립중앙의료원 전국 병·의원 찾기 서비스](https://www.data.go.kr/data/15000736/openapi.do)

Flutter가 현재 위치의 위도·경도와 주소에서 얻은 시도·시군구를 Flask로 전달합니다. Flask는 해당 지역 병원을 조회한 뒤 GPS 직선거리를 계산하여 가까운 순서로 반환합니다. API 키는 `server/.env`에만 저장합니다.

## 가까운 병원 조회

### 요청

- 방식: `GET`
- 주소: `/api/hospitals/nearby`

### 요청값

| 이름 | 의미 | 필수 | 기본값 |
|---|---|---|---|
| `latitude` | 현재 위치의 위도 | 필수 | 없음 |
| `longitude` | 현재 위치의 경도 | 필수 | 없음 |
| `sido` | 현재 주소의 시도(예: 경상북도) | 필수 | 없음 |
| `sigungu` | 현재 주소의 시군구(예: 봉화군) | 필수 | 없음 |
| `radius_m` | 검색 반경(100~50,000m) | 선택 | 20,000 |
| `limit` | 결과 개수(1~50개) | 선택 | 20 |
| `keyword` | 현재 지역 안에서 검색할 병원 이름 | 선택 | 없음 |

국립중앙의료원 API는 위도·경도를 검색값으로 받지 않습니다. 따라서 Flutter가 GPS 좌표를 주소로 변환하여 `sido`, `sigungu`도 함께 보내야 합니다.

### 요청 예시

```text
GET /api/hospitals/nearby?latitude=36.893633&longitude=128.7312033&sido=경상북도&sigungu=봉화군
```

### 성공 응답 예시

```json
{
  "success": true,
  "data": {
    "hospitals": [
      {
        "id": "A2701422",
        "name": "고려연합치과의원",
        "type": "치과의원",
        "phone": "054-674-2875",
        "address": "경상북도 봉화군 봉화읍 봉화로 1146",
        "postal_code": "36239",
        "directions": "봉화웨딩건물 3층",
        "latitude": 36.89073450352211,
        "longitude": 128.73537580055017,
        "distance_m": 493,
        "has_emergency_room": false,
        "emergency_type": "응급의료기관 이외",
        "is_open": true,
        "open_status": "open",
        "open_status_text": "진료시간 기준으로 현재 진료 중입니다.",
        "today_hours": "09:00~17:00",
        "weekly_hours": {
          "monday": "09:00~17:00",
          "tuesday": "09:00~17:00",
          "wednesday": "09:00~17:00",
          "thursday": "09:00~17:00",
          "friday": "09:00~17:00",
          "saturday": null,
          "sunday": null,
          "holiday": null
        }
      }
    ]
  },
  "message": "가까운 병원을 조회했습니다.",
  "source": "국립중앙의료원",
  "updated_at": "2026-08-11T08:30:00Z"
}
```

결과는 가까운 순서로 정렬됩니다. `distance_m`는 GPS 직선거리이므로 실제 도로 이동거리와 다를 수 있습니다.

## 병원 이름 검색

### 요청

- 방식: `GET`
- 주소: `/api/hospitals/search`

### 요청값

| 이름 | 의미 | 필수 | 기본값 |
|---|---|---|---|
| `keyword` | 병원 이름 검색어 | 필수 | 없음 |
| `latitude` | 현재 위치의 위도 | 선택 | 없음 |
| `longitude` | 현재 위치의 경도 | 선택 | 없음 |
| `sido` | 현재 주소의 시도 | 선택 | 없음 |
| `sigungu` | 현재 주소의 시군구 | 선택 | 없음 |
| `radius_m` | 위치 검색 반경 | 선택 | 20,000 |
| `limit` | 결과 개수(1~50개) | 선택 | 20 |

위치 기반 검색을 할 때는 `latitude`, `longitude`, `sido`, `sigungu`를 모두 보냅니다. 위치를 보내지 않으면 전국 병원 이름을 검색하며 `distance_m`은 `null`입니다. `sido`와 `sigungu`만 보내면 해당 지역 안에서 이름을 검색할 수 있습니다.

### 요청 예시

```text
GET /api/hospitals/search?keyword=봉화병원
```

```text
GET /api/hospitals/search?keyword=의원&latitude=36.893633&longitude=128.7312033&sido=경상북도&sigungu=봉화군
```

Flutter 병원 상세 화면은 사용자가 선택한 병원 객체의 이름, 전화번호, 주소, 거리, 진료시간을 그대로 사용합니다. 전화번호가 없으면 전화하기 버튼을 비활성화합니다.

## 운영 여부 주의사항

`is_open`은 국립중앙의료원이 제공한 요일별 진료시간과 현재 한국 시간을 비교한 계산값입니다.

- `true`: 제공된 진료시간 기준으로 현재 진료시간 안에 있음
- `false`: 제공된 진료시간 기준으로 현재 진료시간 밖임
- `null`: 오늘 진료시간 데이터가 없어 판단할 수 없음

병원 사정, 임시 휴진, 점심시간, 공휴일 변경은 실시간으로 반영되지 않을 수 있습니다. 화면에는 `진료시간 기준`이라고 표시하고, 방문 전 전화 확인을 안내해야 합니다. 공휴일 여부는 현재 서버가 자동으로 판별하지 않습니다.

## 오류 코드

| 코드 | 의미 | HTTP 상태 |
|---|---|---|
| `MISSING_LOCATION` | 위도 또는 경도가 없음 | 400 |
| `INVALID_LOCATION` | 위도 또는 경도의 형식이나 범위가 잘못됨 | 400 |
| `MISSING_REGION` | 시도 또는 시군구가 없음 | 400 |
| `INVALID_REGION` | 시도 또는 시군구 형식이 잘못됨 | 400 |
| `INVALID_RADIUS` | 검색 반경이 허용 범위를 벗어남 | 400 |
| `INVALID_LIMIT` | 결과 개수가 허용 범위를 벗어남 | 400 |
| `MISSING_HOSPITAL_QUERY` | 병원 검색어가 없음 | 400 |
| `INVALID_HOSPITAL_QUERY` | 병원 검색어가 100자를 초과함 | 400 |
| `HOSPITAL_API_KEY_MISSING` | 서버에 공공데이터포털 API 키가 설정되지 않음 | 500 |
| `HOSPITAL_DATA_UNAVAILABLE` | 외부 병원 API를 사용할 수 없음 | 502 |

## 서버 환경변수

```dotenv
DATA_GO_KR_API_KEY=공공데이터포털에서_발급받은_디코딩키
```

`.env`와 실제 키는 GitHub나 Flutter 코드에 넣지 않습니다.
