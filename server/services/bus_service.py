from math import asin, cos, radians, sin, sqrt

import requests

from config import TAGO_API_KEY


BUS_STATION_API_URL = (
    "https://apis.data.go.kr/1613000/"
    "BusSttnInfoInqireService/getCrdntPrxmtSttnList"
)
REQUEST_TIMEOUT_SECONDS = 10
EARTH_RADIUS_METERS = 6_371_000


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


def _get_response_items(payload):
    try:
        response_data = payload["response"]
        header = response_data["header"]
        body = response_data["body"]
    except (KeyError, TypeError) as error:
        raise BusServiceError("버스 API 응답 형식이 올바르지 않습니다.") from error

    if str(header.get("resultCode")) != "00":
        raise BusServiceError("버스 API가 오류 응답을 반환했습니다.")

    items_container = body.get("items") or {}
    if not isinstance(items_container, dict):
        return []

    items = items_container.get("item") or []
    if isinstance(items, dict):
        return [items]
    if isinstance(items, list):
        return items
    return []


def get_nearby_stops(latitude, longitude):
    """현재 위치에서 반경 500m 안의 버스정류장을 가까운 순서로 반환합니다."""
    if not TAGO_API_KEY:
        raise BusConfigurationError("TAGO_API_KEY가 설정되지 않았습니다.")

    params = {
        "serviceKey": TAGO_API_KEY,
        "pageNo": 1,
        "numOfRows": 20,
        "_type": "json",
        "gpsLati": latitude,
        "gpsLong": longitude,
    }

    try:
        response = requests.get(
            BUS_STATION_API_URL,
            params=params,
            timeout=REQUEST_TIMEOUT_SECONDS,
        )
        response.raise_for_status()
        payload = response.json()
    except (requests.RequestException, ValueError) as error:
        raise BusServiceError("버스 API 요청에 실패했습니다.") from error

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
