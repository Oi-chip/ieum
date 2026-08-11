from datetime import datetime, timezone

from flask import Blueprint, jsonify, request

if __package__ == "server.routes":
    from ..services.hospital_service import (
        HospitalConfigurationError,
        HospitalServiceError,
        get_nearby_hospitals,
        search_hospitals,
    )
else:
    from services.hospital_service import (
        HospitalConfigurationError,
        HospitalServiceError,
        get_nearby_hospitals,
        search_hospitals,
    )


hospital_blueprint = Blueprint(
    "hospital",
    __name__,
    url_prefix="/api/hospitals",
)


def _error_response(code, message, status_code):
    return jsonify({
        "success": False,
        "error": {
            "code": code,
            "message": message,
        },
    }), status_code


def _parse_location(required=True):
    latitude_text = request.args.get("latitude")
    longitude_text = request.args.get("longitude")

    if latitude_text is None and longitude_text is None and not required:
        return None, None

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


def _parse_positive_integer(name, default, minimum, maximum, error_code):
    value_text = request.args.get(name)
    if value_text is None:
        return default, None

    try:
        value = int(value_text)
    except ValueError:
        value = None

    if value is None or not minimum <= value <= maximum:
        return None, _error_response(
            error_code,
            f"{name} 값은 {minimum}부터 {maximum} 사이의 정수여야 합니다.",
            400,
        )

    return value, None


def _parse_region(required=True):
    sido = request.args.get("sido", "").strip()
    sigungu = request.args.get("sigungu", "").strip()

    if not sido and not sigungu and not required:
        return None, None

    if not sido or not sigungu:
        return None, _error_response(
            "MISSING_REGION",
            "시도와 시군구를 모두 입력해 주세요.",
            400,
        )

    if (
        len(sido) > 30
        or len(sigungu) > 30
        or not sido.isprintable()
        or not sigungu.isprintable()
    ):
        return None, _error_response(
            "INVALID_REGION",
            "시도 또는 시군구의 형식이 올바르지 않습니다.",
            400,
        )

    return (sido, sigungu), None


def _parse_options():
    radius_m, error = _parse_positive_integer(
        "radius_m", 20000, 100, 50000, "INVALID_RADIUS"
    )
    if error is not None:
        return None, error

    limit, error = _parse_positive_integer(
        "limit", 20, 1, 50, "INVALID_LIMIT"
    )
    if error is not None:
        return None, error

    return (radius_m, limit), None


def _hospital_error_response():
    return _error_response(
        "HOSPITAL_DATA_UNAVAILABLE",
        "병원 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.",
        502,
    )


def _success_response(hospitals, message):
    return jsonify({
        "success": True,
        "data": {
            "hospitals": hospitals,
        },
        "message": message,
        "source": "국립중앙의료원",
        "updated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    })


@hospital_blueprint.get("/nearby")
def nearby_hospitals():
    location, error = _parse_location()
    if error is not None:
        return error

    region, error = _parse_region()
    if error is not None:
        return error

    options, error = _parse_options()
    if error is not None:
        return error

    keyword = request.args.get("keyword", "").strip()
    if len(keyword) > 100:
        return _error_response(
            "INVALID_HOSPITAL_QUERY",
            "병원 검색어는 100자 이하로 입력해 주세요.",
            400,
        )

    latitude, longitude = location
    sido, sigungu = region
    radius_m, limit = options

    try:
        hospitals = get_nearby_hospitals(
            latitude,
            longitude,
            sido,
            sigungu,
            radius_m=radius_m,
            keyword=keyword or None,
            limit=limit,
        )
    except HospitalConfigurationError:
        return _error_response(
            "HOSPITAL_API_KEY_MISSING",
            "서버에 병원 API 키가 설정되지 않았습니다.",
            500,
        )
    except HospitalServiceError:
        return _hospital_error_response()

    return _success_response(hospitals, "가까운 병원을 조회했습니다.")


@hospital_blueprint.get("/search")
def hospital_search():
    keyword = request.args.get("keyword", "").strip()
    if not keyword:
        return _error_response(
            "MISSING_HOSPITAL_QUERY",
            "병원 이름을 입력해 주세요.",
            400,
        )
    if len(keyword) > 100:
        return _error_response(
            "INVALID_HOSPITAL_QUERY",
            "병원 검색어는 100자 이하로 입력해 주세요.",
            400,
        )

    location, error = _parse_location(required=False)
    if error is not None:
        return error

    region, error = _parse_region(required=False)
    if error is not None:
        return error

    if location is not None and region is None:
        return _error_response(
            "MISSING_REGION",
            "위치로 검색할 때는 시도와 시군구가 필요합니다.",
            400,
        )

    options, error = _parse_options()
    if error is not None:
        return error

    radius_m, limit = options
    latitude, longitude = location if location is not None else (None, None)
    sido, sigungu = region if region is not None else (None, None)

    try:
        hospitals = search_hospitals(
            keyword,
            latitude=latitude,
            longitude=longitude,
            sido=sido,
            sigungu=sigungu,
            radius_m=radius_m,
            limit=limit,
        )
    except HospitalConfigurationError:
        return _error_response(
            "HOSPITAL_API_KEY_MISSING",
            "서버에 병원 API 키가 설정되지 않았습니다.",
            500,
        )
    except HospitalServiceError:
        return _hospital_error_response()

    return _success_response(hospitals, "병원 검색을 완료했습니다.")
