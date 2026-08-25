from datetime import datetime, timezone

from flask import Blueprint, jsonify, request

if __package__ == "server.routes":
    from ..services.bus_service import (
        BusConfigurationError,
        BusServiceError,
        get_bus_arrivals,
        get_bus_route,
        get_nearby_bus_overview,
        get_nearby_stops,
        get_stop_routes,
        search_bus_routes,
    )
else:
    from services.bus_service import (
        BusConfigurationError,
        BusServiceError,
        get_bus_arrivals,
        get_bus_route,
        get_nearby_bus_overview,
        get_nearby_stops,
        get_stop_routes,
        search_bus_routes,
    )


bus_blueprint = Blueprint("bus", __name__, url_prefix="/api/bus")


def _error_response(code, message, status_code):
    return jsonify({
        "success": False,
        "error": {
            "code": code,
            "message": message,
        },
    }), status_code


def _parse_location():
    latitude_text = request.args.get("latitude")
    longitude_text = request.args.get("longitude")

    if latitude_text is None or longitude_text is None:
        return None, _error_response(
            "MISSING_LOCATION",
            "위도와 경도를 모두 입력해 주세요.",
            400,
        )

    try:
        latitude = float(latitude_text)
        longitude = float(longitude_text)
    except ValueError:
        return None, _error_response(
            "INVALID_LOCATION",
            "위도와 경도는 숫자로 입력해 주세요.",
            400,
        )

    if not -90 <= latitude <= 90 or not -180 <= longitude <= 180:
        return None, _error_response(
            "INVALID_LOCATION",
            "위도 또는 경도의 범위가 올바르지 않습니다.",
            400,
        )

    return (latitude, longitude), None


def _parse_stop():
    city_code = request.args.get("city_code", "").strip()
    stop_id = request.args.get("stop_id", "").strip()

    if not city_code or not stop_id:
        return None, _error_response(
            "MISSING_STOP",
            "도시 코드와 정류장 ID를 모두 입력해 주세요.",
            400,
        )

    if (
        not city_code.isdigit()
        or len(city_code) > 9
        or not stop_id.isalnum()
        or len(stop_id) > 30
    ):
        return None, _error_response(
            "INVALID_STOP",
            "도시 코드 또는 정류장 ID가 올바르지 않습니다.",
            400,
        )

    return (city_code, stop_id), None


def _parse_route():
    city_code = request.args.get("city_code", "").strip()
    route_id = request.args.get("route_id", "").strip()

    if not city_code or not route_id:
        return None, _error_response(
            "MISSING_ROUTE",
            "도시 코드와 노선 ID를 모두 입력해 주세요.",
            400,
        )

    if (
        not city_code.isdigit()
        or len(city_code) > 9
        or not route_id.isalnum()
        or len(route_id) > 30
    ):
        return None, _error_response(
            "INVALID_ROUTE",
            "도시 코드 또는 노선 ID가 올바르지 않습니다.",
            400,
        )

    return (city_code, route_id), None

def _parse_destination():
    destination = request.args.get(
        "destination",
        "",
    ).strip()

    if not destination:
        return None, _error_response(
            "MISSING_DESTINATION",
            "도착지역을 입력해 주세요.",
            400,
        )

    if len(destination) > 50:
        return None, _error_response(
            "INVALID_DESTINATION",
            "도착지역 입력값이 너무 깁니다.",
            400,
        )

    return destination, None

def _parse_bus_search():
    location, error = _parse_location()
    if error is not None:
        return None, error

    destination = request.args.get("destination", "").strip()
    if not destination:
        return None, _error_response(
            "MISSING_DESTINATION",
            "도착지를 입력해 주세요.",
            400,
        )
    if len(destination) > 80 or not any(
        character.isalnum() for character in destination
    ):
        return None, _error_response(
            "INVALID_DESTINATION",
            "도착지는 80자 이하로 입력해 주세요.",
            400,
        )

    origin_stop_id = request.args.get("origin_stop_id", "").strip() or None
    origin_city_code = request.args.get("origin_city_code", "").strip() or None
    if (origin_stop_id is None) != (origin_city_code is None):
        return None, _error_response(
            "INVALID_ORIGIN_STOP",
            "출발 정류장 ID와 도시 코드를 함께 입력해 주세요.",
            400,
        )
    if origin_stop_id is not None and (
        not origin_stop_id.isalnum() or len(origin_stop_id) > 30
    ):
        return None, _error_response(
            "INVALID_ORIGIN_STOP",
            "출발 정류장 ID가 올바르지 않습니다.",
            400,
        )
    if origin_city_code is not None and (
        not origin_city_code.isdigit() or len(origin_city_code) > 9
    ):
        return None, _error_response(
            "INVALID_ORIGIN_STOP",
            "출발 정류장 도시 코드가 올바르지 않습니다.",
            400,
        )

    return (
        *location,
        destination,
        origin_stop_id,
        origin_city_code,
    ), None


@bus_blueprint.get("/nearby")
def nearby_bus_stops():
    location, error = _parse_location()
    if error is not None:
        return error

    latitude, longitude = location

    try:
        stops = get_nearby_stops(latitude, longitude)
    except BusConfigurationError:
        return _error_response(
            "BUS_API_KEY_MISSING",
            "서버에 버스 API 키가 설정되지 않았습니다.",
            500,
        )
    except BusServiceError:
        return _error_response(
            "BUS_DATA_UNAVAILABLE",
            "버스 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.",
            502,
        )

    return jsonify({
        "success": True,
        "data": {
            "stops": stops,
        },
        "message": "가까운 버스정류장을 조회했습니다.",
        "source": "국토교통부 TAGO",
        "updated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    })


@bus_blueprint.get("/overview")
def nearby_bus_overview():
    location, error = _parse_location()
    if error is not None:
        return error

    try:
        overview = get_nearby_bus_overview(*location)
    except BusConfigurationError:
        return _error_response(
            "BUS_API_KEY_MISSING",
            "서버에 버스 API 키가 설정되지 않았습니다.",
            500,
        )
    except BusServiceError:
        return _error_response(
            "BUS_DATA_UNAVAILABLE",
            "주변 버스 노선을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.",
            502,
        )

    return jsonify({
        "success": True,
        "data": overview,
        "message": "주변 모든 정류장의 버스 노선을 조회했습니다.",
        "source": "국토교통부 TAGO",
        "updated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    })


@bus_blueprint.get("/arrivals")
def bus_arrivals():
    stop, error = _parse_stop()
    if error is not None:
        return error

    city_code, stop_id = stop

    try:
        arrivals = get_bus_arrivals(city_code, stop_id)
    except BusConfigurationError:
        return _error_response(
            "BUS_API_KEY_MISSING",
            "서버에 버스 API 키가 설정되지 않았습니다.",
            500,
        )
    except BusServiceError:
        return _error_response(
            "BUS_DATA_UNAVAILABLE",
            "버스 도착정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.",
            502,
        )

    return jsonify({
        "success": True,
        "data": {
            "city_code": city_code,
            "stop_id": stop_id,
            "arrivals": arrivals,
        },
        "message": "버스 도착정보를 조회했습니다.",
        "source": "국토교통부 TAGO",
        "updated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    })


@bus_blueprint.get("/route")
def bus_route():
    route_query, error = _parse_route()
    if error is not None:
        return error

    city_code, route_id = route_query

    try:
        route = get_bus_route(city_code, route_id)
    except BusConfigurationError:
        return _error_response(
            "BUS_API_KEY_MISSING",
            "서버에 버스 API 키가 설정되지 않았습니다.",
            500,
        )
    except BusServiceError:
        return _error_response(
            "BUS_DATA_UNAVAILABLE",
            "버스 노선정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.",
            502,
        )

    if route is None:
        return _error_response(
            "BUS_ROUTE_NOT_FOUND",
            "해당 버스 노선정보를 찾을 수 없습니다.",
            404,
        )

    return jsonify({
        "success": True,
        "data": {
            "city_code": city_code,
            "route": route,
        },
        "message": "버스 노선정보를 조회했습니다.",
        "source": "국토교통부 TAGO",
        "updated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    })


@bus_blueprint.get("/stop-routes")
def stop_routes():
    stop, error = _parse_stop()
    if error is not None:
        return error

    city_code, stop_id = stop

    try:
        routes = get_stop_routes(city_code, stop_id)
    except BusConfigurationError:
        return _error_response(
            "BUS_API_KEY_MISSING",
            "서버에 버스 API 키가 설정되지 않았습니다.",
            500,
        )
    except BusServiceError:
        return _error_response(
            "BUS_DATA_UNAVAILABLE",
            "경유 버스 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.",
            502,
        )

    return jsonify({
        "success": True,
        "data": {
            "city_code": city_code,
            "stop_id": stop_id,
            "routes": routes,
        },
        "message": "정류장을 지나는 버스 목록을 조회했습니다.",
        "source": "국토교통부 TAGO",
        "updated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    })


@bus_blueprint.get("/search")
def search_direct_bus_routes():
    search_query, error = _parse_bus_search()
    if error is not None:
        return error

    (
        latitude,
        longitude,
        destination,
        origin_stop_id,
        origin_city_code,
    ) = search_query
    try:
        result = search_bus_routes(
            latitude,
            longitude,
            destination,
            origin_stop_id,
            origin_city_code,
        )
    except BusConfigurationError:
        return _error_response(
            "BUS_API_KEY_MISSING",
            "서버에 버스 API 키가 설정되지 않았습니다.",
            500,
        )
    except BusServiceError:
        return _error_response(
            "BUS_DATA_UNAVAILABLE",
            "출발지에서 도착지까지의 버스 노선을 확인하지 못했습니다.",
            502,
        )

    return jsonify({
        "success": True,
        "data": result,
        "message": "출발지에서 도착지까지 운행하는 직통 버스를 조회했습니다.",
        "source": "국토교통부 TAGO",
        "updated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    })
