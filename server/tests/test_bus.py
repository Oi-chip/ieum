import unittest
from unittest.mock import Mock, patch

from app import app
from services.bus_service import BusServiceError, get_bus_arrivals, get_nearby_stops


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

    @patch("routes.bus.get_bus_arrivals")
    def test_bus_arrivals_success(self, mock_get_bus_arrivals):
        mock_get_bus_arrivals.return_value = [{
            "route_id": "DJB30300002",
            "bus_number": "5",
            "route_type": "마을버스",
            "remaining_stops": 3,
            "arrival_seconds": 125,
            "arrival_minutes": 3,
            "vehicle_type": "저상버스",
        }]

        response = self.client.get(
            "/api/bus/arrivals?city_code=25&stop_id=DJB8001793"
        )

        data = response.get_json()
        self.assertEqual(response.status_code, 200)
        self.assertTrue(data["success"])
        self.assertEqual(data["data"]["arrivals"][0]["arrival_minutes"], 3)

    def test_bus_arrivals_requires_city_code_and_stop_id(self):
        response = self.client.get("/api/bus/arrivals?city_code=25")

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json()["error"]["code"], "MISSING_STOP")

    def test_bus_arrivals_rejects_invalid_city_code(self):
        response = self.client.get(
            "/api/bus/arrivals?city_code=wrong&stop_id=DJB8001793"
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json()["error"]["code"], "INVALID_STOP")

    @patch("routes.bus.get_bus_arrivals")
    def test_bus_arrivals_handles_external_api_error(self, mock_get_bus_arrivals):
        mock_get_bus_arrivals.side_effect = BusServiceError("test error")

        response = self.client.get(
            "/api/bus/arrivals?city_code=25&stop_id=DJB8001793"
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

    @patch("services.bus_service.TAGO_API_KEY", "test-key")
    @patch("services.bus_service.requests.get")
    def test_get_bus_arrivals_converts_minutes_and_sorts_data(self, mock_get):
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
                                "routeid": "LATE",
                                "routeno": "20",
                                "routetp": "간선버스",
                                "arrprevstationcnt": 5,
                                "arrtime": 301,
                                "vehicletp": "일반버스",
                            },
                            {
                                "routeid": "SOON",
                                "routeno": "10",
                                "routetp": "마을버스",
                                "arrprevstationcnt": 1,
                                "arrtime": 61,
                                "vehicletp": "저상버스",
                            },
                        ]
                    }
                },
            }
        }
        mock_get.return_value = response

        arrivals = get_bus_arrivals("25", "DJB8001793")

        self.assertEqual(
            [arrival["route_id"] for arrival in arrivals],
            ["SOON", "LATE"],
        )
        self.assertEqual(arrivals[0]["arrival_minutes"], 2)
        self.assertEqual(arrivals[1]["arrival_minutes"], 6)


if __name__ == "__main__":
    unittest.main()
