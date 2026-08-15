from collections import defaultdict
from datetime import datetime, time, timedelta, timezone

import requests

if __package__ == "server.services":
    from ..config import DATA_GO_API_KEY
else:
    from config import DATA_GO_API_KEY

WEATHER_API_URL = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst"
REQUEST_TIMEOUT_SECONDS = 10
KST = timezone(timedelta(hours=9), name="KST")
ISSUE_HOURS = (2, 5, 8, 11, 14, 17, 20, 23)
SKY_LABELS = {"1": "맑음", "3": "구름많음", "4": "흐림"}
PTY_LABELS = {"1": "비", "2": "비 또는 눈", "3": "눈", "4": "소나기", "5": "빗방울", "6": "빗방울 또는 눈날림", "7": "눈날림"}


class WeatherServiceError(Exception):
    """기상청 데이터를 정상적으로 가져오지 못했을 때 발생합니다."""


class WeatherConfigurationError(WeatherServiceError):
    """날씨 API 설정이 빠졌을 때 발생합니다."""


class WeatherForecastNotFound(WeatherServiceError):
    """기상청 단기예보 제공 범위 밖의 날짜를 요청했을 때 발생합니다."""


def _latest_base_datetime(now=None):
    current = (now or datetime.now(KST)).astimezone(KST)
    available = current - timedelta(minutes=10)
    candidates = [hour for hour in ISSUE_HOURS if hour <= available.hour]
    if candidates:
        return datetime.combine(available.date(), time(max(candidates)), tzinfo=KST)
    return datetime.combine(available.date() - timedelta(days=1), time(23), tzinfo=KST)


def _response_items(payload):
    try:
        response = payload["response"]
        header = response["header"]
        body = response["body"]
    except (KeyError, TypeError) as error:
        raise WeatherServiceError("기상청 API 응답 형식이 올바르지 않습니다.") from error
    if str(header.get("resultCode")) != "00":
        raise WeatherServiceError(header.get("resultMsg") or "기상청 API 오류")
    items = (body.get("items") or {}).get("item") or []
    if isinstance(items, dict):
        return [items]
    if not isinstance(items, list):
        raise WeatherServiceError("기상청 예보 목록 형식이 올바르지 않습니다.")
    return items


def _number(value, number_type=float):
    try:
        return number_type(value)
    except (TypeError, ValueError):
        return None


def _condition(values):
    precipitation = str(values.get("PTY", "0"))
    if precipitation != "0":
        return PTY_LABELS.get(precipitation, "강수")
    return SKY_LABELS.get(str(values.get("SKY", "")), "알 수 없음")


def get_weather_forecast(nx, ny, forecast_date=None, now=None):
    if not DATA_GO_API_KEY:
        raise WeatherConfigurationError("data_go_API_KEY가 설정되지 않았습니다.")
    current = (now or datetime.now(KST)).astimezone(KST)
    target_date = forecast_date or current.date()
    base = _latest_base_datetime(current)
    params = {
        "serviceKey": DATA_GO_API_KEY, "pageNo": 1, "numOfRows": 1000,
        "dataType": "JSON", "base_date": base.strftime("%Y%m%d"),
        "base_time": base.strftime("%H%M"), "nx": nx, "ny": ny,
    }
    try:
        response = requests.get(WEATHER_API_URL, params=params, timeout=REQUEST_TIMEOUT_SECONDS)
        response.raise_for_status()
        items = _response_items(response.json())
    except requests.RequestException as error:
        raise WeatherServiceError("기상청 API 요청에 실패했습니다.") from error
    except ValueError as error:
        raise WeatherServiceError("기상청 API가 JSON을 반환하지 않았습니다.") from error

    grouped = defaultdict(dict)
    for item in items:
        try:
            forecast_at = datetime.strptime(
                f"{item['fcstDate']}{str(item['fcstTime']).zfill(4)}", "%Y%m%d%H%M"
            ).replace(tzinfo=KST)
            category = str(item["category"])
        except (KeyError, TypeError, ValueError):
            continue
        if forecast_at.date() == target_date:
            grouped[forecast_at][category] = item.get("fcstValue")

    hourly = []
    for forecast_at, values in sorted(grouped.items()):
        if "TMP" not in values:
            continue
        hourly.append({
            "forecast_at": forecast_at.isoformat(),
            "temperature_c": _number(values.get("TMP")),
            "condition": _condition(values),
            "precipitation_probability": _number(values.get("POP"), int),
            "precipitation_type": _number(values.get("PTY"), int),
            "snow_cm": _number(values.get("SNO")),
            "wind_speed_ms": _number(values.get("WSD")),
        })
    if not hourly:
        raise WeatherForecastNotFound("요청한 날짜의 단기예보가 없습니다.")
    current_forecast = min(hourly, key=lambda item: abs(datetime.fromisoformat(item["forecast_at"]) - current))
    temperature = current_forecast["temperature_c"]
    return {
        "grid": {"nx": nx, "ny": ny}, "forecast_date": target_date.isoformat(),
        "base_at": base.isoformat(), "current": current_forecast, "hourly": hourly,
        "summary": f"{target_date.month}월 {target_date.day}일 날씨는 {current_forecast['condition']}, 기온은 {temperature:g}도입니다.",
    }
