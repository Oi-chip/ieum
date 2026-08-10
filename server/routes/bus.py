from datetime import datetime, timezone

from flask import Blueprint, jsonify, request

from services.bus_service import (
    BusConfigurationError,
    BusServiceError,
    get_nearby_stops,
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
