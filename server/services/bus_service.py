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
# TAGO 목록 API는 페이지당 최대 1,000건을 받는다.
API_PAGE_SIZE = 1_000
MAX_API_ITEMS = 10_000
BUS_SEARCH_WORKERS = 4
ROUTE_CACHE_TTL_SECONDS = 6 * 60 * 60
ROUTE_CACHE_MAX_ENTRIES = 512
NEARBY_CACHE_TTL_SECONDS = 5 * 60
STOP_ROUTES_CACHE_TTL_SECONDS = 5 * 60
ARRIVAL_CACHE_TTL_SECONDS = 15
CITY_CODE_CACHE_TTL_SECONDS = 24 * 60 * 60

# 시 경계 노선은 운행 주체의 도시 코드까지 조회해야 빠지지 않는다.
ROUTE_PROVIDER_CITY_CODES = {
    "37410": ("37060",),
    "37060": ("37410",),
}

# TAGO의 예전 노선 번호를 현재 지역 노선 번호로 보정한다.
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
            # 요청 URL에 API 키가 들어 있으므로 원본 예외를 연결하지 않는다.
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
            # 필수 값이 빠진 정류장은 결과에서 뺀다.
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

    # updowncd는 순환 구간에서 흔들려서 nodeord로 순서를 맞춘다.
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
        # 이 API만 정류장 키가 소문자 nodeid다.
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


def _normalize_search_text(value):
    return "".join(
        character.casefold()
        for character in str(value or "")
        if character.isalnum()
    )


def _route_key(route):
    return (str(route["city_code"]), str(route["route_id"]))


def _get_cached_nearby_stops(latitude, longitude):
    key = (round(float(latitude), 6), round(float(longitude), 6))
    return _nearby_stops_cache.get_or_load(
        key,
        lambda: get_nearby_stops(latitude, longitude),
    )


def _get_cached_stop_routes(
    city_code,
    stop_id,
    additional_provider_city_codes=(),
):
    provider_city_codes = _provider_city_codes(
        city_code,
        additional_provider_city_codes,
    )
    normalized_stop_id = str(stop_id)

    def get_cached_provider_routes(provider_city_code, provider_stop_id):
        key = (str(provider_city_code), str(provider_stop_id))
        return _stop_routes_cache.get_or_load(
            key,
            lambda: _load_stop_routes_for_provider(*key),
        )

    return _collect_stop_routes_for_providers(
        provider_city_codes,
        normalized_stop_id,
        get_cached_provider_routes,
    )


def _get_cached_arrivals(city_code, stop_id):
    key = (str(city_code), str(stop_id))
    return _arrival_cache.get_or_load(
        key,
        lambda: get_bus_arrivals(*key),
    )


def _load_stop_bundle(
    stop,
    include_arrivals=True,
    additional_provider_city_codes=(),
):
    routes = []
    arrivals_by_route = {}
    unavailable_provider_codes = []
    unavailable_arrival_provider_codes = []
    route_error = False
    arrival_error = False

    try:
        routes, unavailable_provider_codes = _get_cached_stop_routes(
            stop["city_code"],
            stop["id"],
            additional_provider_city_codes,
        )
    except BusServiceError:
        route_error = True

    if include_arrivals:
        arrival_provider_codes = sorted({
            route["city_code"] for route in routes
        })
        for provider_city_code in arrival_provider_codes:
            try:
                arrivals = _get_cached_arrivals(
                    provider_city_code,
                    stop["id"],
                )
            except BusServiceError:
                unavailable_arrival_provider_codes.append(provider_city_code)
                continue

            for arrival in arrivals:
                # 공급기관별 응답은 도착이 빠른 순서다.
                arrivals_by_route.setdefault(
                    (provider_city_code, arrival["route_id"]),
                    arrival,
                )

        arrival_error = bool(arrival_provider_codes) and (
            len(unavailable_arrival_provider_codes)
            == len(arrival_provider_codes)
        )

    return {
        "stop": stop,
        "routes": routes,
        "arrivals": arrivals_by_route,
        "route_error": route_error,
        "arrival_error": arrival_error,
        "unavailable_provider_codes": unavailable_provider_codes,
        "unavailable_arrival_provider_codes": (
            unavailable_arrival_provider_codes
        ),
    }


def _collect_nearby_route_candidates(
    latitude,
    longitude,
    origin_stop_id=None,
    origin_city_code=None,
    include_arrivals=True,
    additional_provider_city_codes=(),
):
    nearby_stops = _get_cached_nearby_stops(latitude, longitude)
    origin_stops = nearby_stops
    if origin_stop_id:
        origin_stops = [
            stop for stop in nearby_stops
            if stop["id"] == str(origin_stop_id)
            and (
                origin_city_code is None
                or stop["city_code"] == str(origin_city_code)
            )
        ]
        if not origin_stops:
            raise BusServiceError("선택한 출발 정류장이 현재 위치 주변에 없습니다.")

    bundles = []
    if origin_stops:
        worker_count = min(BUS_SEARCH_WORKERS, len(origin_stops))
        with ThreadPoolExecutor(max_workers=worker_count) as executor:
            futures = {
                executor.submit(
                    _load_stop_bundle,
                    stop,
                    include_arrivals,
                    additional_provider_city_codes,
                ): stop
                for stop in origin_stops
            }
            for future in as_completed(futures):
                bundles.append(future.result())

    if origin_stops and bundles and all(bundle["route_error"] for bundle in bundles):
        raise BusServiceError("출발지 주변의 버스 노선을 불러오지 못했습니다.")

    candidates = {}
    for bundle in bundles:
        stop = bundle["stop"]
        for route in bundle["routes"]:
            key = _route_key(route)
            candidate = candidates.setdefault(key, {
                "route": route,
                "boardings": [],
            })
            candidate["boardings"].append({
                "stop": stop,
                "arrival": bundle["arrivals"].get(key),
            })

    return {
        "nearby_stops": nearby_stops,
        "origin_stops": origin_stops,
        "bundles": bundles,
        "candidates": candidates,
        "unavailable_stop_count": sum(
            1 for bundle in bundles if bundle["route_error"]
        ),
        "unavailable_provider_count": sum(
            len(bundle["unavailable_provider_codes"])
            for bundle in bundles
        ),
        "unavailable_arrival_provider_count": sum(
            len(bundle.get("unavailable_arrival_provider_codes", []))
            for bundle in bundles
        ),
        "arrival_information_unavailable": (
            include_arrivals
            and bool(candidates)
            and all(
                bundle["arrival_error"]
                for bundle in bundles
                if bundle["routes"]
            )
        ),
    }


def _boarding_priority(boarding):
    arrival = boarding["arrival"] or {}
    return (
        boarding["stop"]["distance_m"],
        arrival.get("arrival_seconds", 999_999),
    )


def _route_option(route, boarding):
    result = {
        **route,
        "route_key": f'{route["city_code"]}:{route["route_id"]}',
        "boarding_stop": boarding["stop"],
        "remaining_stops": None,
        "arrival_seconds": None,
        "arrival_minutes": None,
        "vehicle_type": None,
    }
    if boarding["arrival"] is not None:
        result.update({
            "remaining_stops": boarding["arrival"].get("remaining_stops"),
            "arrival_seconds": boarding["arrival"].get("arrival_seconds"),
            "arrival_minutes": boarding["arrival"].get("arrival_minutes"),
            "vehicle_type": boarding["arrival"].get("vehicle_type"),
        })
    return result


def get_nearby_bus_overview(latitude, longitude):
    """반경 500m의 모든 정류장과 경유 노선을 한 번에 반환합니다."""
    collected = _collect_nearby_route_candidates(latitude, longitude)
    routes = []
    for candidate in collected["candidates"].values():
        boarding = min(candidate["boardings"], key=_boarding_priority)
        routes.append(_route_option(candidate["route"], boarding))

    routes.sort(key=lambda route: (
        route["arrival_minutes"] is None,
        route["arrival_minutes"] or 0,
        route["boarding_stop"]["distance_m"],
        route["bus_number"],
    ))
    partial = bool(
        collected["unavailable_stop_count"]
        or collected["unavailable_provider_count"]
        or collected["unavailable_arrival_provider_count"]
    )
    return {
        "stops": collected["nearby_stops"],
        "routes": routes,
        "origin_stop_count": len(collected["origin_stops"]),
        "route_count": len(routes),
        "arrival_information_unavailable": (
            collected["arrival_information_unavailable"]
        ),
        "partial": partial,
        "unavailable_stop_count": collected["unavailable_stop_count"],
        "unavailable_provider_count": collected["unavailable_provider_count"],
        "unavailable_arrival_provider_count": (
            collected["unavailable_arrival_provider_count"]
        ),
    }


def _boarding_stop_indices(route_stops, nearby_stop):
    nearby_stop_id = nearby_stop.get("id")
    exact_matches = [
        index
        for index, route_stop in enumerate(route_stops)
        if nearby_stop_id and route_stop.get("id") == nearby_stop_id
    ]
    if exact_matches:
        return exact_matches

    nearby_stop_number = nearby_stop.get("number")
    number_matches = [
        index
        for index, route_stop in enumerate(route_stops)
        if nearby_stop_number
        and route_stop.get("number") == nearby_stop_number
    ]
    if number_matches:
        return number_matches

    nearby_name = _normalize_search_text(nearby_stop.get("name"))
    nearby_latitude = nearby_stop.get("latitude")
    nearby_longitude = nearby_stop.get("longitude")
    if (
        not nearby_name
        or nearby_latitude is None
        or nearby_longitude is None
    ):
        return []

    distance_matches = []
    for index, route_stop in enumerate(route_stops):
        if _normalize_search_text(route_stop.get("name")) != nearby_name:
            continue
        route_latitude = route_stop.get("latitude")
        route_longitude = route_stop.get("longitude")
        if route_latitude is None or route_longitude is None:
            continue
        distance = _distance_in_meters(
            route_latitude,
            route_longitude,
            nearby_latitude,
            nearby_longitude,
        )
        if distance <= 120:
            distance_matches.append((index, distance))

    if not distance_matches:
        return []
    shortest_distance = min(distance for _, distance in distance_matches)
    return [
        index
        for index, distance in distance_matches
        if distance == shortest_distance
    ]


def _find_direct_journey(route_stops, boardings, destination):
    destination_text = _normalize_search_text(destination)
    matches = []

    for boarding in boardings:
        boarding_indices = _boarding_stop_indices(
            route_stops,
            boarding["stop"],
        )
        for boarding_index in boarding_indices:
            route_stop = route_stops[boarding_index]
            for destination_index in range(boarding_index + 1, len(route_stops)):
                destination_stop = route_stops[destination_index]
                destination_name = _normalize_search_text(destination_stop["name"])
                destination_number = _normalize_search_text(
                    destination_stop.get("number")
                )
                if (
                    destination_text not in destination_name
                    and destination_text != destination_number
                ):
                    continue
                matches.append({
                    "boarding": boarding,
                    "boarding_stop": route_stop,
                    "destination_stop": destination_stop,
                    "stops_between": destination_index - boarding_index,
                })
                break

    if not matches:
        return None
    return min(matches, key=lambda match: (
        match["boarding"]["stop"]["distance_m"],
        match["stops_between"],
        (match["boarding"]["arrival"] or {}).get(
            "arrival_seconds",
            999_999,
        ),
    ))


def _search_route_candidate(candidate, destination):
    route = candidate["route"]
    route_stops = None
    route_stops_error = False
    try:
        route_stops = _get_route_stops(route["city_code"], route["route_id"])
    except BusServiceError:
        route_stops_error = True

    route_stops_incomplete = route_stops_error or not route_stops
    journey = None
    if route_stops:
        journey = _find_direct_journey(
            route_stops,
            candidate["boardings"],
            destination,
        )

    normalized_destination = _normalize_search_text(destination)
    summary_destination_match = normalized_destination in _normalize_search_text(
        route.get("end_stop")
    )
    if journey is None:
        if route_stops or not summary_destination_match:
            return None, route_stops_incomplete

    if journey is None:
        boarding = min(candidate["boardings"], key=_boarding_priority)
        journey = {
            "boarding": boarding,
            "boarding_stop": None,
            "destination_stop": None,
            "stops_between": None,
        }

    route_info = None
    route_info_error = False
    try:
        route_info = _get_route_info(route["city_code"], route["route_id"])
    except BusServiceError:
        route_info_error = True

    detail = _build_route(
        route["city_code"],
        route["route_id"],
        route_info,
        route_stops if route_stops else None,
        route,
    )
    result = _route_option(route, journey["boarding"])
    result.update({
        "bus_number": detail["number"] or route["bus_number"],
        "api_bus_number": detail["api_number"] or route["api_bus_number"],
        "route_type": detail["type"] or route.get("route_type"),
        "start_stop": detail["start_stop"] or route.get("start_stop"),
        "end_stop": detail["end_stop"] or route.get("end_stop"),
        "via_stop": detail["via_stop"],
        "first_bus_time": detail["first_bus_time"],
        "last_bus_time": detail["last_bus_time"],
        "weekday_interval_minutes": detail["weekday_interval_minutes"],
        "saturday_interval_minutes": detail["saturday_interval_minutes"],
        "sunday_interval_minutes": detail["sunday_interval_minutes"],
        "matched_stop": (
            journey["destination_stop"]["name"]
            if journey["destination_stop"] is not None
            else route.get("end_stop") or destination
        ),
        "destination_stop": journey["destination_stop"],
        "boarding_order": (
            journey["boarding_stop"]["order"]
            if journey["boarding_stop"] is not None
            else None
        ),
        "destination_order": (
            journey["destination_stop"]["order"]
            if journey["destination_stop"] is not None
            else None
        ),
        "stops_between": journey["stops_between"],
        "route_stop_count": len(route_stops or []),
        "data_complete": detail["data_complete"],
        "unavailable_fields": detail["unavailable_fields"],
    })
    return result, (
        route_stops_incomplete
        or route_info_error
        or not detail["data_complete"]
    )


def _attach_search_arrivals(results):
    stops_by_key = {}
    for result in results:
        stop = result["boarding_stop"]
        key = (result["city_code"], stop["id"])
        stops_by_key[key] = {
            "city_code": result["city_code"],
            "id": stop["id"],
        }

    arrivals_by_stop = {}
    unavailable_count = 0
    if stops_by_key:
        worker_count = min(BUS_SEARCH_WORKERS, len(stops_by_key))
        with ThreadPoolExecutor(max_workers=worker_count) as executor:
            futures = {
                executor.submit(
                    _get_cached_arrivals,
                    stop["city_code"],
                    stop["id"],
                ): key
                for key, stop in stops_by_key.items()
            }
            for future in as_completed(futures):
                key = futures[future]
                try:
                    arrivals = future.result()
                except BusServiceError:
                    unavailable_count += 1
                    continue
                arrivals_by_route = {}
                for arrival in arrivals:
                    arrivals_by_route.setdefault(arrival["route_id"], arrival)
                arrivals_by_stop[key] = arrivals_by_route

    for result in results:
        stop = result["boarding_stop"]
        arrival = arrivals_by_stop.get(
            (result["city_code"], stop["id"]),
            {},
        ).get(result["route_id"])
        if arrival is None:
            continue
        result.update({
            "remaining_stops": arrival.get("remaining_stops"),
            "arrival_seconds": arrival.get("arrival_seconds"),
            "arrival_minutes": arrival.get("arrival_minutes"),
            "vehicle_type": arrival.get("vehicle_type"),
        })

    return unavailable_count


def search_bus_routes(
    latitude,
    longitude,
    destination,
    origin_stop_id=None,
    origin_city_code=None,
):
    """출발지 주변에서 목적지까지 순방향으로 운행하는 직통 노선을 찾습니다."""
    provider_discovery_unavailable = False
    try:
        destination_provider_city_codes = _destination_provider_city_codes(
            destination
        )
    except BusServiceError:
        destination_provider_city_codes = ()
        provider_discovery_unavailable = True

    collected = _collect_nearby_route_candidates(
        latitude,
        longitude,
        origin_stop_id,
        origin_city_code,
        False,
        destination_provider_city_codes,
    )
    candidates = list(collected["candidates"].values())
    results = []
    unavailable_route_count = 0
    incomplete_result_count = 0

    if candidates:
        worker_count = min(BUS_SEARCH_WORKERS, len(candidates))
        with ThreadPoolExecutor(max_workers=worker_count) as executor:
            futures = {
                executor.submit(
                    _search_route_candidate,
                    candidate,
                    destination,
                ): candidate
                for candidate in candidates
            }
            for future in as_completed(futures):
                try:
                    result, incomplete = future.result()
                except BusServiceError:
                    unavailable_route_count += 1
                    continue
                if result is not None:
                    results.append(result)
                    if incomplete:
                        incomplete_result_count += 1
                elif incomplete:
                    unavailable_route_count += 1

    unavailable_arrival_stop_count = _attach_search_arrivals(results)

    results.sort(key=lambda route: (
        route["boarding_stop"]["distance_m"],
        route["stops_between"] is None,
        route["stops_between"] or 0,
        route["arrival_minutes"] is None,
        route["arrival_minutes"] or 0,
        route["bus_number"],
    ))
    partial = bool(
        collected["unavailable_stop_count"]
        or collected["unavailable_provider_count"]
        or unavailable_route_count
        or incomplete_result_count
        or unavailable_arrival_stop_count
        or provider_discovery_unavailable
    )
    return {
        "destination": destination,
        "origin_stops": collected["origin_stops"],
        "routes": results,
        "origin_stop_count": len(collected["origin_stops"]),
        "searched_route_count": len(candidates),
        "route_count": len(results),
        "arrival_information_unavailable": bool(results) and (
            unavailable_arrival_stop_count
            == len({
                (
                    route["city_code"],
                    route["boarding_stop"]["id"],
                )
                for route in results
            })
        ),
        "partial": partial,
        "provider_discovery_unavailable": provider_discovery_unavailable,
        "destination_provider_city_codes": list(
            destination_provider_city_codes
        ),
        "unavailable_stop_count": collected["unavailable_stop_count"],
        "unavailable_provider_count": collected["unavailable_provider_count"],
        "unavailable_route_count": unavailable_route_count,
        "incomplete_result_count": incomplete_result_count,
        "unavailable_arrival_stop_count": unavailable_arrival_stop_count,
    }
