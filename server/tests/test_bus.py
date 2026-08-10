import unittest
from unittest.mock import Mock, patch

from app import app
from services.bus_service import BusServiceError, get_nearby_stops


class BusRouteTest(unittest.TestCase):
    def setUp(self):
        app.config["TESTING"] = True
        self.client = app.test_client()

    @patch("routes.bus.get_nearby_stops")
    def test_nearby_bus_stops_success(self, mock_get_nearby_stops):
        mock_get_nearby_stops.return_value = [{
            "id": "DJB8002012",
            "city_code": "25",
            "name": "성북3통굿개말길",
            "number": "40600",
            "latitude": 36.298546,
            "longitude": 127.29593,
            "distance_m": 206,
        }]

        response = self.client.get(
            "/api/bus/nearby?latitude=36.3&longitude=127.3"
        )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.get_json()["success"])
        self.assertEqual(response.get_json()["data"]["stops"][0]["id"], "DJB8002012")

    def test_nearby_bus_stops_requires_both_coordinates(self):
        response = self.client.get("/api/bus/nearby?latitude=36.3")

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json()["error"]["code"], "MISSING_LOCATION")

    def test_nearby_bus_stops_rejects_invalid_coordinates(self):
        response = self.client.get(
            "/api/bus/nearby?latitude=200&longitude=127.3"
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json()["error"]["code"], "INVALID_LOCATION")

    @patch("routes.bus.get_nearby_stops")
    def test_nearby_bus_stops_handles_external_api_error(self, mock_get_nearby_stops):
        mock_get_nearby_stops.side_effect = BusServiceError("test error")

        response = self.client.get(
            "/api/bus/nearby?latitude=36.3&longitude=127.3"
        )

        self.assertEqual(response.status_code, 502)
        self.assertEqual(response.get_json()["error"]["code"], "BUS_DATA_UNAVAILABLE")


class BusServiceTest(unittest.TestCase):
    @patch("services.bus_service.TAGO_API_KEY", "test-key")
    @patch("services.bus_service.requests.get")
    def test_get_nearby_stops_converts_and_sorts_data(self, mock_get):
        response = Mock()
        response.raise_for_status.return_value = None
        response.json.return_value = {
            "response": {
                "header": {
                    "resultCode": "00",
                    "resultMsg": "NORMAL SERVICE.",
                },
                "body": {
                    "items": {
                        "item": [
                            {
                                "nodeid": "FAR",
                                "citycode": 25,
                                "nodenm": "먼 정류장",
                                "nodeno": 2,
                                "gpslati": 36.31,
                                "gpslong": 127.31,
                            },
                            {
                                "nodeid": "NEAR",
                                "citycode": 25,
                                "nodenm": "가까운 정류장",
                                "nodeno": 1,
                                "gpslati": 36.3001,
                                "gpslong": 127.3001,
                            },
                        ]
                    }
                },
            }
        }
        mock_get.return_value = response

        stops = get_nearby_stops(36.3, 127.3)

        self.assertEqual([stop["id"] for stop in stops], ["NEAR", "FAR"])
        self.assertEqual(stops[0]["city_code"], "25")
        self.assertEqual(stops[0]["number"], "1")
        self.assertIn("distance_m", stops[0])


if __name__ == "__main__":
    unittest.main()
