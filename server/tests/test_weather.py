import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from app import app
from services.weather_service import _latest_base_datetime


class WeatherRouteTest(unittest.TestCase):
    def setUp(self):
        app.config["TESTING"] = True
        self.client = app.test_client()

    @patch("routes.weather.get_weather_forecast")
    def test_weather_success(self, mock_get_weather):
        mock_get_weather.return_value = {"current": {"condition": "맑음"}}
        response = self.client.get("/api/weather?nx=90&ny=106&date=2026-08-14")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.get_json()["success"])

    def test_weather_rejects_invalid_grid(self):
        response = self.client.get("/api/weather?nx=wrong&ny=106")
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json()["error"]["code"], "INVALID_GRID")

    def test_weather_rejects_invalid_date(self):
        response = self.client.get("/api/weather?date=2026/08/14")
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json()["error"]["code"], "INVALID_DATE")

    def test_latest_base_time_accounts_for_api_delay(self):
        now = datetime(2026, 8, 14, 5, 5, tzinfo=timezone(timedelta(hours=9)))
        self.assertEqual(_latest_base_datetime(now).hour, 2)


if __name__ == "__main__":
    unittest.main()
