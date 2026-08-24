from concurrent.futures import ThreadPoolExecutor, as_completed
from copy import deepcopy
from math import asin, ceil, cos, radians, sin, sqrt
from threading import Lock
from time import monotonic

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
BUS_CITY_CODE_API_URL = (
    "https://apis.data.go.kr/1613000/"
    "BusSttnInfoInqireService/getCtyCodeList"
)
REQUEST_TIMEOUT_SECONDS = 10
ARRIVAL_REQUEST_TIMEOUT_SECONDS = 4
EARTH_RADIUS_METERS = 6_371_000
# TAGO accepts 1,000 rows for station and route-stop lists. Fewer pages preserve
# the daily request quota while totalCount-based pagination still handles larger results.
API_PAGE_SIZE = 1_000
MAX_API_ITEMS = 10_000
BUS_SEARCH_WORKERS = 4
ROUTE_CACHE_TTL_SECONDS = 6 * 60 * 60
ROUTE_CACHE_MAX_ENTRIES = 512
NEARBY_CACHE_TTL_SECONDS = 5 * 60
STOP_ROUTES_CACHE_TTL_SECONDS = 5 * 60
ARRIVAL_CACHE_TTL_SECONDS = 15
CITY_CODE_CACHE_TTL_SECONDS = 24 * 60 * 60

# TAGO는 시 경계를 넘는 노선을 운행 주체의 도시코드로만 반환합니다.
# 봉화 정류장 ID를 봉화군 코드로만 조회하면 영주시 33/533번 노선이 누락됩니다.
ROUTE_PROVIDER_CITY_CODES = {
    "37410": ("37060",),
    "37060": ("37410",),
}

# TAGO returns an outdated route number for this Bonghwa-to-Yeongju route.
# Keep the number shown in the app aligned with the current local route number.
ROUTE_NUMBER_OVERRIDES = {
    ("37410", "TSB371000049"): "33",
}


class _TtlCache:
    def __init__(self, ttl_seconds, max_entries):
        self._ttl_seconds = ttl_seconds
        self._max_entries = max_entries
        self._values = {}
        self._lock = Lock()

    def get_or_load(self, key, loader, should_cache=None):
        now = monotonic()
        with self._lock:
            cached = self._values.get(key)
            if cached is not None and cached[0] > now:
                return deepcopy(cached[1])
            if cached is not None:
                self._values.pop(key, None)

        value = loader()
        if should_cache is not None and not should_cache(value):
            return value

        expires_at = monotonic() + self._ttl_seconds
        with self._lock:
            if len(self._values) >= self._max_entries:
                oldest_key = min(
                    self._values,
                    key=lambda item: self._values[item][0],
                )
                self._values.pop(oldest_key, None)
            self._values[key] = (expires_at, deepcopy(value))
        return value

    def clear(self):
        with self._lock:
            self._values.clear()


_route_info_cache = _TtlCache(
    ROUTE_CACHE_TTL_SECONDS,
    ROUTE_CACHE_MAX_ENTRIES,
)
_route_stops_cache = _TtlCache(
    ROUTE_CACHE_TTL_SECONDS,
    ROUTE_CACHE_MAX_ENTRIES,
)
_nearby_stops_cache = _TtlCache(NEARBY_CACHE_TTL_SECONDS, 256)
_stop_routes_cache = _TtlCache(STOP_ROUTES_CACHE_TTL_SECONDS, 1_024)
_arrival_cache = _TtlCache(ARRIVAL_CACHE_TTL_SECONDS, 1_024)
_city_codes_cache = _TtlCache(CITY_CODE_CACHE_TTL_SECONDS, 1)


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


def _get_all_response_items(
    url,
    params,
    timeout_seconds=REQUEST_TIMEOUT_SECONDS,
):
    all_items = []
    page_number = 1

    while len(all_items) < MAX_API_ITEMS:
        payload = _request_bus_api(
            url,
            {
                **params,
                "pageNo": page_number,
                "numOfRows": API_PAGE_SIZE,
            },
            timeout_seconds,
        )
        page_items = _get_response_items(payload)
        all_items.extend(page_items)

        body = _get_response_body(payload)
        try:
            total_count = int(body.get("totalCount", len(all_items)))
        except (TypeError, ValueError):
            total_count = len(all_items)

        if len(all_items) >= total_count:
            return all_items
        if not page_items:
            raise BusServiceError("버스 API가 전체 결과를 반환하지 않았습니다.")
        page_number += 1

    raise BusServiceError("버스 API 결과가 허용된 최대 항목 수를 초과했습니다.")


def _request_bus_api(url, params, timeout_seconds=REQUEST_TIMEOUT_SECONDS):
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
                timeout=timeout_seconds,
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
        except ValueError:
            if attempt == 0:
                continue
            raise BusServiceError("버스 API 응답을 해석하지 못했습니다.") from None
        except requests.RequestException:
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
    items = _get_all_response_items(BUS_STATION_API_URL, {
        "gpsLati": latitude,
        "gpsLong": longitude,
    })

    stops_by_id = {}
    for item in items:
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
        stops_by_id.setdefault(stop_id, {
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

    return sorted(
        stops_by_id.values(),
        key=lambda stop: stop["distance_m"],
    )


def get_bus_arrivals(city_code, stop_id):
    """선택한 정류장에 도착할 버스를 빠른 순서로 반환합니다."""
    items = _get_all_response_items(
        BUS_ARRIVAL_API_URL,
        {
            "cityCode": city_code,
            "nodeId": stop_id,
        },
        ARRIVAL_REQUEST_TIMEOUT_SECONDS,
    )

    arrivals = []
    for item in items:
        try:
            arrival_seconds = int(item["arrtime"])
            remaining_stops = int(item["arrprevstationcnt"])
            route_id = str(item["routeid"])
            bus_number = _route_number(city_code, route_id, item["routeno"])
        except (KeyError, TypeError, ValueError):
            continue

        arrivals.append({
            "route_id": route_id,
            "bus_number": bus_number,
            "api_bus_number": str(item["routeno"]),
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

def _provider_city_codes(city_code, additional_provider_city_codes=()):
    return tuple(dict.fromkeys((
        str(city_code),
        *ROUTE_PROVIDER_CITY_CODES.get(str(city_code), ()),
        *(str(code) for code in additional_provider_city_codes),
    )))


def _load_city_codes():
    payload = _request_bus_api(BUS_CITY_CODE_API_URL, {})
    city_codes = []
    for item in _get_response_items(payload):
        try:
            city_codes.append({
                "code": str(item["citycode"]),
                "name": str(item["cityname"]),
            })
        except (KeyError, TypeError):
            continue
    return city_codes


def _get_city_codes():
    return _city_codes_cache.get_or_load(
        "all",
        _load_city_codes,
        should_cache=bool,
    )


def _city_name_aliases(city_name):
    aliases = set()
    for city_name_part in str(city_name or "").split("/"):
        normalized_name = _normalize_search_text(city_name_part)
        if not normalized_name:
            continue
        aliases.add(normalized_name)
        for suffix in (
            "특별자치시",
            "특별자치도",
            "특별시",
            "광역시",
            "시",
            "군",
            "구",
            "도",
        ):
            normalized_suffix = _normalize_search_text(suffix)
            if normalized_name.endswith(normalized_suffix):
                base_name = normalized_name[:-len(normalized_suffix)]
                if len(base_name) >= 2:
                    aliases.add(base_name)
                break
    return aliases


def _destination_provider_city_codes(destination):
    normalized_destination = _normalize_search_text(destination)
    matches = []
    for city in _get_city_codes():
        aliases = _city_name_aliases(city["name"])
        if any(
            len(alias) >= 2 and normalized_destination.startswith(alias)
            for alias in aliases
        ):
            matches.append(city["code"])
    return tuple(dict.fromkeys(matches))


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


def _load_route_info(city_code, route_id):
    route_payload = _request_bus_api(BUS_ROUTE_INFO_API_URL, {
        "cityCode": city_code,
        "routeId": route_id,
    })
    route_items = _get_response_items(route_payload)
    return route_items[0] if route_items else None


def _load_route_stops(city_code, route_id):
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

    # TAGO의 updowncd는 순환노선 중간에 바뀌거나 문서 밖 값(2)을 줄 수 있습니다.
    # 실제 탑승 순서는 노선 전체에서 증가하는 nodeord를 기준으로 판단합니다.
    return sorted(stops, key=lambda stop: stop["order"])


def _get_route_info(city_code, route_id):
    key = (str(city_code), str(route_id))
    return _route_info_cache.get_or_load(
        key,
        lambda: _load_route_info(*key),
        should_cache=lambda value: value is not None,
    )


def _get_route_stops(city_code, route_id):
    key = (str(city_code), str(route_id))
    return _route_stops_cache.get_or_load(
        key,
        lambda: _load_route_stops(*key),
        should_cache=bool,
    )


def _build_route(city_code, route_id, item, stops, fallback_route=None):
    fallback_route = fallback_route or {}
    unavailable_fields = []

    if item is None:
        unavailable_fields.append("route_info")
        number = fallback_route.get("bus_number")
        route = {
            "id": str(route_id),
            "number": str(number) if number is not None else None,
            "api_number": fallback_route.get("api_bus_number", number),
            "type": fallback_route.get("route_type"),
            "start_stop": fallback_route.get("start_stop"),
            "end_stop": fallback_route.get("end_stop"),
            "first_bus_time": None,
            "last_bus_time": None,
            "weekday_interval_minutes": None,
            "saturday_interval_minutes": None,
            "sunday_interval_minutes": None,
        }
    else:
        try:
            route = {
                "id": str(item["routeid"]),
                "number": _route_number(city_code, route_id, item["routeno"]),
                "api_number": str(item["routeno"]),
                "type": item.get("routetp") or fallback_route.get("route_type"),
                "start_stop": (
                    item.get("startnodenm") or fallback_route.get("start_stop")
                ),
                "end_stop": item.get("endnodenm") or fallback_route.get("end_stop"),
                "first_bus_time": _format_bus_time(item.get("startvehicletime")),
                "last_bus_time": _format_bus_time(item.get("endvehicletime")),
                "weekday_interval_minutes": _optional_integer(
                    item.get("intervaltime")
                ),
                "saturday_interval_minutes": _optional_integer(
                    item.get("intervalsattime")
                ),
                "sunday_interval_minutes": _optional_integer(
                    item.get("intervalsuntime")
                ),
            }
        except (KeyError, TypeError) as error:
            raise BusServiceError("노선 기본정보 형식이 올바르지 않습니다.") from error

    if stops is None:
        unavailable_fields.append("route_stops")
        stops = []

    route["stops"] = stops
    route["via_stop"] = None
    if (
        route["start_stop"]
        and route["start_stop"] == route["end_stop"]
        and stops
    ):
        route["via_stop"] = _turnaround_stop_name(
            stops,
            route["start_stop"],
        )
    route["data_complete"] = not unavailable_fields
    route["unavailable_fields"] = unavailable_fields
    return route


def get_bus_route(city_code, route_id, fallback_route=None):
    """노선정보와 정류장을 결합하며 한 API가 실패해도 가능한 정보는 반환합니다."""
    info = None
    stops = None
    errors = []

    try:
        info = _get_route_info(city_code, route_id)
    except BusServiceError as error:
        errors.append(error)

    try:
        stops = _get_route_stops(city_code, route_id)
    except BusServiceError as error:
        errors.append(error)

    if info is None and not stops and fallback_route is None:
        if errors:
            raise errors[0]
        return None

    return _build_route(
        city_code,
        route_id,
        info,
        stops if stops else None,
        fallback_route,
    )


def clear_bus_route_cache():
    """테스트 또는 운영 갱신 시 버스 조회 캐시를 비웁니다."""
    _route_info_cache.clear()
    _route_stops_cache.clear()
    _nearby_stops_cache.clear()
    _stop_routes_cache.clear()
    _arrival_cache.clear()
    _city_codes_cache.clear()


def _load_stop_routes_for_provider(provider_city_code, stop_id):
    route_items = _get_all_response_items(BUS_STOP_ROUTES_API_URL, {
        "cityCode": provider_city_code,
        # 이 오퍼레이션은 다른 TAGO API와 달리 소문자 nodeid를 사용합니다.
        "nodeid": stop_id,
    })
    routes = []
    for item in route_items:
        try:
            routes.append({
                "route_id": str(item["routeid"]),
                "city_code": str(provider_city_code),
                "bus_number": _route_number(
                    provider_city_code,
                    item["routeid"],
                    item["routeno"],
                ),
                "api_bus_number": str(item["routeno"]),
                "route_type": item.get("routetp"),
                "start_stop": item.get("startnodenm"),
                "end_stop": item.get("endnodenm"),
            })
        except (KeyError, TypeError):
            continue
    return routes


def _collect_stop_routes_for_providers(
    provider_city_codes,
    stop_id,
    provider_loader,
):
    routes_by_key = {}
    successful_request = False
    last_error = None
    unavailable_provider_codes = []

    for provider_city_code in provider_city_codes:
        try:
            routes = provider_loader(provider_city_code, stop_id)
            successful_request = True
        except BusServiceError as error:
            last_error = error
            unavailable_provider_codes.append(provider_city_code)
            continue

        for route in routes:
            route_key = (route["city_code"], route["route_id"])
            routes_by_key.setdefault(route_key, route)

    if not successful_request and last_error is not None:
        raise last_error

    return list(routes_by_key.values()), unavailable_provider_codes


def _get_stop_routes_with_status(
    city_code,
    stop_id,
    additional_provider_city_codes=(),
):
    provider_city_codes = _provider_city_codes(
        city_code,
        additional_provider_city_codes,
    )
    return _collect_stop_routes_for_providers(
        provider_city_codes,
        str(stop_id),
        _load_stop_routes_for_provider,
    )


def get_stop_routes(city_code, stop_id):
    """선택한 정류장을 지나는 버스 노선 목록을 반환합니다."""
    routes, _ = _get_stop_routes_with_status(city_code, stop_id)
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

