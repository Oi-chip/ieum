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
SEARCH_STOP_LIMIT = 5


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

    try:
        response = requests.get(
            url,
            params=request_params,
            timeout=REQUEST_TIMEOUT_SECONDS,
        )
        response.raise_for_status()
        return response.json()
    except (requests.RequestException, ValueError):
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

def get_route_stops(city_code, route_id):
    """목적지 검색에 사용할 노선 정류장 목록만 반환합니다."""
    stop_items = _get_all_response_items(
        BUS_ROUTE_STOPS_API_URL,
        {
            "cityCode": city_code,
            "routeId": route_id,
        },
    )

    stops = []

    for stop_item in stop_items:
        try:
            stop = {
                "id": str(stop_item["nodeid"]),
                "name": str(stop_item["nodenm"]),
                "order": int(stop_item["nodeord"]),
            }
        except (KeyError, TypeError, ValueError):
            continue

        stops.append(stop)

    return sorted(
        stops,
        key=lambda stop: stop["order"],
    )

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
            "number": str(item["routeno"]),
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
    return route


def get_stop_routes(city_code, stop_id):
    """선택한 정류장을 지나는 버스 노선 목록을 반환합니다."""
    route_items = _get_all_response_items(BUS_STOP_ROUTES_API_URL, {
        "cityCode": city_code,
        # 이 오퍼레이션은 다른 TAGO API와 달리 소문자 nodeid를 사용합니다.
        "nodeid": stop_id,
    })

    routes = []
    for item in route_items:
        try:
            route = {
                "route_id": str(item["routeid"]),
                "bus_number": str(item["routeno"]),
                "route_type": item.get("routetp"),
                "start_stop": item.get("startnodenm"),
                "end_stop": item.get("endnodenm"),
            }
        except (KeyError, TypeError):
            continue

        routes.append(route)

    return routes

def search_buses_by_destination(
    latitude,
    longitude,
    destination,
):
    """주변 정류장에서 목적지로 갈 수 있는 버스를 검색합니다."""
    destination = destination.strip().lower()

    nearby_stops = get_nearby_stops(
        latitude,
        longitude,
    )

    if not nearby_stops:
        return {
            "stop": None,
            "buses": [],
        }

    search_stops = nearby_stops[:SEARCH_STOP_LIMIT]

    # 같은 노선의 전체 정류장을 반복 요청하지 않도록
    # 이번 검색 요청 안에서 캐시합니다.
    route_stops_cache = {}

    for stop in search_stops:
        city_code = stop["city_code"]
        stop_id = stop["id"]

        routes = get_stop_routes(
            city_code,
            stop_id,
        )

        if not routes:
            continue

        matched_routes = []

        for route in routes:
            route_id = route["route_id"]

            # 이미 조회했던 노선이면 공공데이터 API를 다시 호출하지 않습니다.
            if route_id in route_stops_cache:
                route_stops = route_stops_cache[route_id]
            else:
                route_stops = get_route_stops(
                    city_code,
                    route_id,
                )

                route_stops_cache[route_id] = route_stops

            # 현재 정류장의 순번 확인
            current_stop = next(
                (
                    route_stop
                    for route_stop in route_stops
                    if route_stop["id"] == stop_id
                ),
                None,
            )

            if current_stop is None:
                continue

            current_order = current_stop["order"]

            # 현재 정류장보다 뒤에 있는 정류장 중 목적지를 검색
            matched_stop = next(
                (
                    route_stop
                    for route_stop in route_stops
                    if (
                        route_stop["order"] > current_order
                        and destination
                        in route_stop["name"].lower()
                    )
                ),
                None,
            )

            if matched_stop is None:
                continue

            matched_routes.append({
                "route": route,
                "matched_stop": matched_stop,
            })

        # 이 정류장에서 목적지로 가는 노선을 찾은 경우에만
        # 실시간 도착정보를 한 번 조회합니다.
        if matched_routes:
            arrivals = get_bus_arrivals(
                city_code,
                stop_id,
            )

            arrival_by_route_id = {
                arrival["route_id"]: arrival
                for arrival in arrivals
            }

            buses = []

            for matched in matched_routes:
                route = matched["route"]
                matched_stop = matched["matched_stop"]

                arrival = arrival_by_route_id.get(
                    route["route_id"]
                )

                buses.append({
                    "route_id": route["route_id"],
                    "bus_number": route["bus_number"],
                    "route_type": route.get("route_type"),
                    "start_stop": route.get("start_stop"),
                    "end_stop": route.get("end_stop"),
                    "matched_stop": matched_stop["name"],
                    "remaining_stops": (
                        arrival["remaining_stops"]
                        if arrival is not None
                        else None
                    ),
                    "arrival_minutes": (
                        arrival["arrival_minutes"]
                        if arrival is not None
                        else None
                    ),
                })

            return {
                "stop": stop,
                "buses": buses,
            }

    return {
        "stop": None,
        "buses": [],
    }

