from datetime import datetime, timedelta, timezone
from math import asin, cos, radians, sin, sqrt
from xml.etree import ElementTree

import requests

if __package__ == "server.services":
    from ..config import data_go_API_KEY
else:
    from config import data_go_API_KEY


HOSPITAL_API_URL = (
    "https://apis.data.go.kr/B552657/"
    "HsptlAsembySearchService/getHsptlMdcncListInfoInqire"
)
REQUEST_TIMEOUT_SECONDS = 10
EARTH_RADIUS_METERS = 6_371_000
UPSTREAM_PAGE_SIZE = 1000
MAX_UPSTREAM_PAGES = 5
KOREA_TIMEZONE = timezone(timedelta(hours=9))
DAY_NAMES = {
    1: "monday",
    2: "tuesday",
    3: "wednesday",
    4: "thursday",
    5: "friday",
    6: "saturday",
    7: "sunday",
    8: "holiday",
}


class HospitalServiceError(Exception):
    """병원 데이터를 정상적으로 가져오지 못했을 때 발생합니다."""


class HospitalConfigurationError(HospitalServiceError):
    """병원 API 설정이 비어 있을 때 발생합니다."""


def _distance_in_meters(start_latitude, start_longitude, end_latitude, end_longitude):
    latitude_difference = radians(end_latitude - start_latitude)
    longitude_difference = radians(end_longitude - start_longitude)
    value = (
        sin(latitude_difference / 2) ** 2
        + cos(radians(start_latitude))
        * cos(radians(end_latitude))
        * sin(longitude_difference / 2) ** 2
    )
    return round(2 * EARTH_RADIUS_METERS * asin(sqrt(value)))


def _optional_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _element_text(element, name):
    child = element.find(name)
    if child is None or child.text is None:
        return None

    value = child.text.strip()
    return value or None


def _parse_hospital_response(xml_content):
    try:
        root = ElementTree.fromstring(xml_content)
    except (ElementTree.ParseError, TypeError) as error:
        raise HospitalServiceError("병원 API 응답 형식이 올바르지 않습니다.") from error

    result_code = root.findtext("./header/resultCode")
    if result_code is None:
        result_code = root.findtext(".//cmmMsgHeader/returnReasonCode")

    if str(result_code).strip() not in {"00", "0000"}:
        raise HospitalServiceError("병원 API가 오류 응답을 반환했습니다.")

    body = root.find("./body")
    if body is None:
        raise HospitalServiceError("병원 API 응답 형식이 올바르지 않습니다.")

    items = body.findall("./items/item")
    try:
        total_count = int(body.findtext("totalCount", str(len(items))))
    except (TypeError, ValueError):
        total_count = len(items)

    return items, total_count


def _request_hospital_page(params, page_no=1, num_of_rows=UPSTREAM_PAGE_SIZE):
    if not data_go_API_KEY:
        raise HospitalConfigurationError("data_go_API_KEY가 설정되지 않았습니다.")

    request_params = {
        "serviceKey": data_go_API_KEY,
        "pageNo": page_no,
        "numOfRows": num_of_rows,
        **params,
    }

    try:
        response = requests.get(
            HOSPITAL_API_URL,
            params=request_params,
            timeout=REQUEST_TIMEOUT_SECONDS,
        )
        response.raise_for_status()
    except requests.RequestException:
        # requests 오류에는 API 키가 포함된 전체 요청 주소가 들어갈 수 있습니다.
        raise HospitalServiceError("병원 API 요청에 실패했습니다.") from None

    return _parse_hospital_response(response.content)


def _request_all_hospitals(params):
    all_items = []

    for page_no in range(1, MAX_UPSTREAM_PAGES + 1):
        items, total_count = _request_hospital_page(params, page_no=page_no)
        all_items.extend(items)

        if len(all_items) >= total_count or not items:
            return all_items

    raise HospitalServiceError("병원 목록이 허용된 페이지 수를 초과했습니다.")


def _format_api_time(value):
    if value is None:
        return None

    digits = str(value).strip().zfill(4)
    if not digits.isdigit() or len(digits) != 4:
        return None

    hour = int(digits[:2])
    minute = int(digits[2:])
    if minute > 59 or hour > 24 or (hour == 24 and minute != 0):
        return None

    return f"{hour:02d}:{minute:02d}"


def _hours_for_day(item, day_number):
    start = _format_api_time(_element_text(item, f"dutyTime{day_number}s"))
    end = _format_api_time(_element_text(item, f"dutyTime{day_number}c"))
    if start is None or end is None:
        return None
    return f"{start}~{end}"


def _weekly_hours(item):
    return {
        day_name: _hours_for_day(item, day_number)
        for day_number, day_name in DAY_NAMES.items()
    }


def _open_status(item, now):
    today_hours = _hours_for_day(item, now.isoweekday())
    if today_hours is None:
        return None, "unknown", "진료 여부는 병원에 전화로 확인해 주세요.", None

    start_text, end_text = today_hours.split("~")
    start_minutes = int(start_text[:2]) * 60 + int(start_text[3:])
    end_minutes = int(end_text[:2]) * 60 + int(end_text[3:])
    current_minutes = now.hour * 60 + now.minute

    if end_minutes >= start_minutes:
        is_open = start_minutes <= current_minutes < end_minutes
    else:
        is_open = current_minutes >= start_minutes or current_minutes < end_minutes

    if is_open:
        return True, "open", "진료시간 기준으로 현재 진료 중입니다.", today_hours
    return False, "closed", "진료시간 기준으로 현재 진료시간이 아닙니다.", today_hours


def _postal_code(item):
    first = _element_text(item, "postCdn1")
    second = _element_text(item, "postCdn2")
    if first and second:
        return f"{first}{second}"
    return first or second


def _convert_hospital(item, latitude=None, longitude=None, now=None):
    hospital_id = _element_text(item, "hpid")
    name = _element_text(item, "dutyName")
    if not hospital_id or not name:
        return None

    hospital_latitude = _optional_float(_element_text(item, "wgs84Lat"))
    hospital_longitude = _optional_float(_element_text(item, "wgs84Lon"))

    distance_m = None
    if (
        latitude is not None
        and longitude is not None
        and hospital_latitude is not None
        and hospital_longitude is not None
    ):
        distance_m = _distance_in_meters(
            latitude,
            longitude,
            hospital_latitude,
            hospital_longitude,
        )

    current_time = now or datetime.now(KOREA_TIMEZONE)
    is_open, open_status, open_status_text, today_hours = _open_status(
        item,
        current_time,
    )

    return {
        "id": hospital_id,
        "name": name,
        "type": _element_text(item, "dutyDivNam"),
        "phone": _element_text(item, "dutyTel1"),
        "address": _element_text(item, "dutyAddr"),
        "postal_code": _postal_code(item),
        "directions": _element_text(item, "dutyMapimg"),
        "latitude": hospital_latitude,
        "longitude": hospital_longitude,
        "distance_m": distance_m,
        "has_emergency_room": _element_text(item, "dutyEryn") == "1",
        "emergency_type": _element_text(item, "dutyEmclsName"),
        "is_open": is_open,
        "open_status": open_status,
        "open_status_text": open_status_text,
        "today_hours": today_hours,
        "weekly_hours": _weekly_hours(item),
    }


def _convert_hospitals(items, latitude=None, longitude=None, now=None):
    hospitals = []
    for item in items:
        hospital = _convert_hospital(item, latitude, longitude, now=now)
        if hospital is not None:
            hospitals.append(hospital)
    return hospitals


def get_nearby_hospitals(
    latitude,
    longitude,
    sido,
    sigungu,
    radius_m=20000,
    keyword=None,
    limit=20,
    now=None,
):
    params = {
        "Q0": sido,
        "Q1": sigungu,
        "ORD": "NAME",
    }
    if keyword:
        params["QN"] = keyword

    items = _request_all_hospitals(params)
    hospitals = _convert_hospitals(items, latitude, longitude, now=now)
    region_prefix = f"{sido} {sigungu}"
    hospitals = [
        hospital
        for hospital in hospitals
        if hospital["distance_m"] is not None
        and hospital["distance_m"] <= radius_m
        and hospital["address"] is not None
        and hospital["address"].startswith(region_prefix)
    ]
    hospitals.sort(key=lambda hospital: hospital["distance_m"])
    return hospitals[:limit]


def search_hospitals(
    keyword,
    latitude=None,
    longitude=None,
    sido=None,
    sigungu=None,
    radius_m=20000,
    limit=20,
    now=None,
):
    if latitude is not None and longitude is not None and sido and sigungu:
        return get_nearby_hospitals(
            latitude,
            longitude,
            sido,
            sigungu,
            radius_m=radius_m,
            keyword=keyword,
            limit=limit,
            now=now,
        )

    params = {
        "QN": keyword,
        "ORD": "NAME",
    }
    if sido and sigungu:
        params.update({"Q0": sido, "Q1": sigungu})

    items, _ = _request_hospital_page(params, num_of_rows=limit)
    return _convert_hospitals(items, now=now)[:limit]
