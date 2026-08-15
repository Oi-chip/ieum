## 날씨 API

기상청 단기예보 API를 호출한다. `server/.env`에 공공데이터포털의 일반 인증키
(Decoding)를 `data_go_API_KEY`로 설정한다.

`GET /api/weather?nx=90&ny=106&date=2026-08-14`

- `nx`, `ny`: 기상청 격자 좌표. 생략 시 봉화군 좌표(90, 106)
- `date`: `YYYY-MM-DD` 예보 날짜. 생략 시 오늘

응답의 `data.current`에는 선택 날짜 중 현재 시각에 가장 가까운 예보가,
`data.hourly`에는 시간별 기온·하늘 상태·강수확률·강수형태·적설·풍속이 담긴다.
