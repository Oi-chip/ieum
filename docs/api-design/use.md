# 예시

# 항목	        내용
# 엔드포인트:	 GET /api/bus/search
# 요청:         파라미터 	origin(출발지, 문자열), destination(도착지, 문자열), date(날짜, YYYY-MM-DD, 선택)
# 성공 응답:	 { "success": true, "data": [{ "route_name": "...",  "scheduled_departure": "09:20", ... }], "source": "...", "updated_at": "..." }
# 실패 응답:	 { "success": false, "error": { "code": "BUS_DATA_UNAVAILABLE", "message": "..." } }
# 담당:	         Backend: OO / Frontend: OO


# 기능별로 엔드포인트, 요청 파라미터, 응답 예시를 표로 정리.