from datetime import date, datetime, timezone

from flask import Blueprint, jsonify, request

if __package__ == "server.routes":
    from ..services.weather_service import WeatherConfigurationError, WeatherForecastNotFound, WeatherServiceError, get_weather_forecast
else:
    from services.weather_service import WeatherConfigurationError, WeatherForecastNotFound, WeatherServiceError, get_weather_forecast

weather_blueprint = Blueprint("weather", __name__, url_prefix="/api/weather")


def _error(code, message, status):
    return jsonify({"success": False, "error": {"code": code, "message": message}}), status


@weather_blueprint.get("")
def weather_forecast():
    try:
        nx = int(request.args.get("nx", "90"))
        ny = int(request.args.get("ny", "106"))
    except ValueError:
        return _error("INVALID_GRID", "nx와 ny는 정수여야 합니다.", 400)
    if not 1 <= nx <= 149 or not 1 <= ny <= 253:
        return _error("INVALID_GRID", "기상청 격자 좌표 범위가 올바르지 않습니다.", 400)
    forecast_date = None
    if request.args.get("date"):
        try:
            forecast_date = date.fromisoformat(request.args["date"])
        except ValueError:
            return _error("INVALID_DATE", "date는 YYYY-MM-DD 형식이어야 합니다.", 400)
    try:
        data = get_weather_forecast(nx, ny, forecast_date)
    except WeatherConfigurationError:
        return _error("WEATHER_API_KEY_MISSING", "날씨 API 키가 설정되지 않았습니다.", 500)
    except WeatherForecastNotFound:
        return _error("WEATHER_FORECAST_NOT_FOUND", "해당 날짜는 아직 단기예보가 제공되지 않습니다.", 404)
    except WeatherServiceError:
        return _error("WEATHER_DATA_UNAVAILABLE", "날씨 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.", 502)
    return jsonify({
        "success": True, "data": data, "message": "날씨 예보를 조회했습니다.",
        "source": "기상청 단기예보",
        "updated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    })
