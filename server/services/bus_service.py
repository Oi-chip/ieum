from math import asin, ceil, cos, radians, sin, sqrt

import requests

if __package__ == "server.services":
    from ..config import data_go_API_KEY
else:
    from config import data_go_API_KEY


BUS_STATION_API_URL = (
    "https://apis.data.go.kr/1613000/"
    "BusSttnInfoInqireService/getCrdntPrxmtSttnList"
)
BUS_STOP_ROUTES_API_URL = (
    "https://apis.data.go.kr/1613000/"
    "BusSttnInfoInqireService/getSttnThrghRouteList"
)
BUS_ARRIVAL_API_URL = (
    "https://apis.data.go.kr/1613000/"
    "ArvlInfoInqireService/getSttnAcctoArvlPrearngeInfoList"
)
BUS_ROUTE_INFO_API_URL = (
    "https://apis.data.go.kr/1613000/"
    "BusRouteInfoInqireService/getRouteInfoIem"
)
BUS_ROUTE_STOPS_API_URL = (
    "https://apis.data.go.kr/1613000/"
    "BusRouteInfoInqireService/getRouteAcctoThrghSttnList"
)
REQUEST_TIMEOUT_SECONDS = 10
EARTH_RADIUS_METERS = 6_371_000
ROUTE_STOPS_PAGE_SIZE = 100
MAX_ROUTE_STOPS_PAGES = 10

# TAGO는 시 경계를 넘는 노선을 운행 주체의 도시코드로만 반환합니다.
# 봉화 정류장 ID를 봉화군 코드로만 조회하면 영주시 33/533번 노선이 누락됩니다.
ROUTE_PROVIDER_CITY_CODES = {
    "37410": ("37060",),
}

# TAGO returns an outdated route number for this Bonghwa-to-Yeongju route.
# Keep the number shown in the app aligned with the current local route number.
ROUTE_NUMBER_OVERRIDES = {
    ("37410", "TSB371000049"): "33",
}


class BusServiceError(Exception):
    """버스 데이터를 정상적으로 가져오지 못했을 때 발생합니다."""


class BusConfigurationError(BusServiceError):
    """버스 API 설정이 빠졌을 때 발생합니다."""


def _distance_in_meters(start_latitude, start_longitude, end_latitude, end_longitude):
    """두 위도·경도 사이의 직선거리를 미터로 계산합니다."""
    latitude_difference = radians(end_latitude - start_latitude)
    longitude_difference = radians(end_longitude - start_longitude)

    value = (
        sin(latitude_difference / 2) ** 2
        + cos(radians(start_latitude))
        * cos(radians(end_latitude))
        * sin(longitude_difference / 2) ** 2
    )

    distance = 2 * EARTH_RADIUS_METERS * asin(sqrt(value))
    return round(distance)


def _get_response_body(payload):
    try:
        response_data = payload["response"]
        header = response_data["header"]
        body = response_data["body"]
    except (KeyError, TypeError) as error:
        raise BusServiceError("버스 API 응답 형식이 올바르지 않습니다.") from error

    if str(header.get("resultCode")) != "00":
        raise BusServiceError("버스 API가 오류 응답을 반환했습니다.")

    if not isinstance(body, dict):
        raise BusServiceError("버스 API 응답 형식이 올바르지 않습니다.")

    return body


def _get_response_items(payload):
    body = _get_response_body(payload)

    items_container = body.get("items") or {}
    if not isinstance(items_container, dict):
        return []

    items = items_container.get("item") or []
    if isinstance(items, dict):
        return [items]
    if isinstance(items, list):
        return items
    return []


def _get_all_response_items(url, params):
    all_items = []

    for page_number in range(1, MAX_ROUTE_STOPS_PAGES + 1):
        payload = _request_bus_api(url, {
            **params,
            "pageNo": page_number,
            "numOfRows": ROUTE_STOPS_PAGE_SIZE,
        })
        page_items = _get_response_items(payload)
        all_items.extend(page_items)

        body = _get_response_body(payload)
        try:
            total_count = int(body.get("totalCount", len(all_items)))
        except (TypeError, ValueError):
            total_count = len(all_items)

        if len(all_items) >= total_count or not page_items:
            return all_items

    raise BusServiceError("노선 정류장 목록이 허용된 페이지 수를 초과했습니다.")


def _request_bus_api(url, params):
    if not data_go_API_KEY:
        raise BusConfigurationError("data_go_API_KEY가 설정되지 않았습니다.")

    request_params = {
        "serviceKey": data_go_API_KEY,
        "pageNo": 1,
        "numOfRows": 20,
        "_type": "json",
        **params,
    }

    for attempt in range(2):
        response = None
        try:
            response = requests.get(
                url,
                params=request_params,
                timeout=REQUEST_TIMEOUT_SECONDS,
            )
            response.raise_for_status()
            payload = response.json()
            if not isinstance(payload, dict) or "response" not in payload:
                if attempt == 0:
                    continue
                raise BusServiceError("버스 API가 일시적인 오류 응답을 반환했습니다.")
            return payload
        except BusServiceError:
            raise
        except (requests.RequestException, ValueError):
            if attempt == 0 and (
                response is None
                or response.status_code >= 500
            ):
                continue
            # requests 오류에는 API 키가 포함된 전체 요청 주소가 들어갈 수 있습니다.
            # 원본 오류를 연결하지 않아 전체 traceback에서도 키가 노출되지 않게 합니다.
            raise BusServiceError("버스 API 요청에 실패했습니다.") from None


def get_nearby_stops(latitude, longitude):
    """현재 위치에서 반경 500m 안의 버스정류장을 가까운 순서로 반환합니다."""
    payload = _request_bus_api(BUS_STATION_API_URL, {
        "gpsLati": latitude,
        "gpsLong": longitude,
    })

    stops = []
    for item in _get_response_items(payload):
        try:
            stop_latitude = float(item["gpslati"])
            stop_longitude = float(item["gpslong"])
            stop_id = str(item["nodeid"])
            stop_name = str(item["nodenm"])
            city_code = str(item["citycode"])
        except (KeyError, TypeError, ValueError):
            # 필수 정보가 없는 정류장은 앱에 잘못된 데이터를 보내지 않고 제외합니다.
            continue

        stop_number = item.get("nodeno")
        stops.append({
            "id": stop_id,
            "city_code": city_code,
            "name": stop_name,
            "number": str(stop_number) if stop_number is not None else None,
            "latitude": stop_latitude,
            "longitude": stop_longitude,
            "distance_m": _distance_in_meters(
                latitude,
                longitude,
                stop_latitude,
                stop_longitude,
            ),
        })

    return sorted(stops, key=lambda stop: stop["distance_m"])


def get_bus_arrivals(city_code, stop_id):
    """선택한 정류장에 도착할 버스를 빠른 순서로 반환합니다."""
    payload = _request_bus_api(BUS_ARRIVAL_API_URL, {
        "cityCode": city_code,
        "nodeId": stop_id,
    })

    arrivals = []
    for item in _get_response_items(payload):
        try:
            arrival_seconds = int(item["arrtime"])
            remaining_stops = int(item["arrprevstationcnt"])
            route_id = str(item["routeid"])
            bus_number = str(item["routeno"])
        except (KeyError, TypeError, ValueError):
            continue

        arrivals.append({
            "route_id": route_id,
            "bus_number": bus_number,
            "route_type": item.get("routetp"),
            "remaining_stops": remaining_stops,
            "arrival_seconds": arrival_seconds,
            "arrival_minutes": ceil(arrival_seconds / 60),
            "vehicle_type": item.get("vehicletp"),
        })

    return sorted(arrivals, key=lambda arrival: arrival["arrival_seconds"])


def _format_bus_time(value):
    if value is None:
        return None

    digits = str(value).strip()
    if not digits.isdigit() or len(digits) > 4:
        return None

    digits = digits.zfill(4)
    return f"{digits[:2]}:{digits[2:]}"


def _optional_integer(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _optional_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _provider_city_codes(city_code):
    return (city_code, *ROUTE_PROVIDER_CITY_CODES.get(city_code, ()))


def _route_number(city_code, route_id, value):
    return ROUTE_NUMBER_OVERRIDES.get(
        (str(city_code), str(route_id)),
        str(value),
    )


def _turnaround_stop_name(stops, origin_name):
    if not stops:
        return None
    origin = stops[0]
    if origin["latitude"] is None or origin["longitude"] is None:
        return None
    candidates = [
        stop for stop in stops
        if stop["latitude"] is not None and stop["longitude"] is not None
    ]
    if not candidates:
        return None
    turnaround = max(
        candidates,
        key=lambda stop: _distance_in_meters(
            origin["latitude"],
            origin["longitude"],
            stop["latitude"],
            stop["longitude"],
        ),
    )
    return turnaround["name"] if turnaround["name"] != origin_name else None


def get_bus_route(city_code, route_id):
    """노선 기본정보와 노선이 지나가는 정류장 전체를 반환합니다."""
    route_payload = _request_bus_api(BUS_ROUTE_INFO_API_URL, {
        "cityCode": city_code,
        "routeId": route_id,
    })
    route_items = _get_response_items(route_payload)

    if not route_items:
        return None

    item = route_items[0]
    try:
        route = {
            "id": str(item["routeid"]),
            "number": _route_number(city_code, route_id, item["routeno"]),
            "type": item.get("routetp"),
            "start_stop": item.get("startnodenm"),
            "end_stop": item.get("endnodenm"),
            "first_bus_time": _format_bus_time(item.get("startvehicletime")),
            "last_bus_time": _format_bus_time(item.get("endvehicletime")),
            "weekday_interval_minutes": _optional_integer(item.get("intervaltime")),
            "saturday_interval_minutes": _optional_integer(item.get("intervalsattime")),
            "sunday_interval_minutes": _optional_integer(item.get("intervalsuntime")),
        }
    except (KeyError, TypeError) as error:
        raise BusServiceError("노선 기본정보 형식이 올바르지 않습니다.") from error

    stop_items = _get_all_response_items(BUS_ROUTE_STOPS_API_URL, {
        "cityCode": city_code,
        "routeId": route_id,
    })

    stops = []
    for stop_item in stop_items:
        try:
            stop = {
                "id": str(stop_item["nodeid"]),
                "name": str(stop_item["nodenm"]),
                "order": int(stop_item["nodeord"]),
                "number": (
                    str(stop_item["nodeno"])
                    if stop_item.get("nodeno") is not None
                    else None
                ),
                "latitude": _optional_float(stop_item.get("gpslati")),
                "longitude": _optional_float(stop_item.get("gpslong")),
                "direction_code": (
                    str(stop_item["updowncd"])
                    if stop_item.get("updowncd") is not None
                    else None
                ),
            }
        except (KeyError, TypeError, ValueError):
            continue

        stops.append(stop)

    route["stops"] = sorted(stops, key=lambda stop: stop["order"])
    route["via_stop"] = None
    if (
        route["start_stop"]
        and route["start_stop"] == route["end_stop"]
        and route["stops"]
    ):
        route["via_stop"] = _turnaround_stop_name(
            route["stops"],
            route["start_stop"],
        )
    return route


def get_stop_routes(city_code, stop_id):
    """선택한 정류장을 지나는 버스 노선 목록을 반환합니다."""
    routes_by_id = {}
    successful_request = False
    last_error = None

    for provider_city_code in _provider_city_codes(city_code):
        try:
            route_items = _get_all_response_items(BUS_STOP_ROUTES_API_URL, {
                "cityCode": provider_city_code,
                # 이 오퍼레이션은 다른 TAGO API와 달리 소문자 nodeid를 사용합니다.
                "nodeid": stop_id,
            })
            successful_request = True
        except BusServiceError as error:
            last_error = error
            continue

        for item in route_items:
            try:
                route = {
                    "route_id": str(item["routeid"]),
                    "city_code": provider_city_code,
                    "bus_number": _route_number(
                        provider_city_code,
                        item["routeid"],
                        item["routeno"],
                    ),
                    "route_type": item.get("routetp"),
                    "start_stop": item.get("startnodenm"),
                    "end_stop": item.get("endnodenm"),
                }
            except (KeyError, TypeError):
                continue

            routes_by_id.setdefault(route["route_id"], route)

    if not successful_request and last_error is not None:
        raise last_error

    return list(routes_by_id.values())
