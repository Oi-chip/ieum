import unittest
import traceback
from unittest.mock import Mock, patch

import requests

from app import app
from services.bus_service import (
    BusServiceError,
    _get_response_items,
    _turnaround_stop_name,
    get_bus_arrivals,
    get_bus_route,
    get_nearby_stops,
    get_stop_routes,
)


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

    @patch("routes.bus.get_bus_route")
    def test_bus_route_success(self, mock_get_bus_route):
        mock_get_bus_route.return_value = {
            "id": "DJB30300002",
            "number": "2",
            "type": "급행버스",
            "start_stop": "봉산동",
            "end_stop": "대전역동광장",
            "first_bus_time": "05:45",
            "last_bus_time": "22:30",
            "weekday_interval_minutes": 12,
            "saturday_interval_minutes": 12,
            "sunday_interval_minutes": 16,
            "stops": [],
        }

        response = self.client.get(
            "/api/bus/route?city_code=25&route_id=DJB30300002"
        )

        data = response.get_json()
        self.assertEqual(response.status_code, 200)
        self.assertTrue(data["success"])
        self.assertEqual(data["data"]["route"]["first_bus_time"], "05:45")

    def test_bus_route_requires_city_code_and_route_id(self):
        response = self.client.get("/api/bus/route?city_code=25")

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json()["error"]["code"], "MISSING_ROUTE")

    @patch("routes.bus.get_bus_route")
    def test_bus_route_returns_not_found(self, mock_get_bus_route):
        mock_get_bus_route.return_value = None

        response = self.client.get(
            "/api/bus/route?city_code=25&route_id=UNKNOWN"
        )

        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.get_json()["error"]["code"], "BUS_ROUTE_NOT_FOUND")

    @patch("routes.bus.get_bus_route")
    def test_bus_route_handles_external_api_error(self, mock_get_bus_route):
        mock_get_bus_route.side_effect = BusServiceError("test error")

        response = self.client.get(
            "/api/bus/route?city_code=25&route_id=DJB30300002"
        )

        self.assertEqual(response.status_code, 502)
        self.assertEqual(response.get_json()["error"]["code"], "BUS_DATA_UNAVAILABLE")

    @patch("routes.bus.get_stop_routes")
    def test_stop_routes_success(self, mock_get_stop_routes):
        mock_get_stop_routes.return_value = [{
            "route_id": "TSB371000001",
            "bus_number": "25",
            "route_type": "농어촌(일반)버스",
            "start_stop": "봉화공용터미널",
            "end_stop": "봉화공용터미널",
        }]

        response = self.client.get(
            "/api/bus/stop-routes?city_code=37410&stop_id=TSB371000038"
        )

        data = response.get_json()
        self.assertEqual(response.status_code, 200)
        self.assertTrue(data["success"])
        self.assertEqual(data["data"]["routes"][0]["bus_number"], "25")

    def test_stop_routes_requires_city_code_and_stop_id(self):
        response = self.client.get("/api/bus/stop-routes?city_code=37410")

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json()["error"]["code"], "MISSING_STOP")

    @patch("routes.bus.get_stop_routes")
    def test_stop_routes_handles_external_api_error(self, mock_get_stop_routes):
        mock_get_stop_routes.side_effect = BusServiceError("test error")

        response = self.client.get(
            "/api/bus/stop-routes?city_code=37410&stop_id=TSB371000038"
        )

        self.assertEqual(response.status_code, 502)
        self.assertEqual(response.get_json()["error"]["code"], "BUS_DATA_UNAVAILABLE")


class BusServiceTest(unittest.TestCase):
    def test_turnaround_stop_uses_farthest_stop_on_circular_route(self):
        stops = [
            {"name": "터미널", "latitude": 36.0, "longitude": 128.0},
            {"name": "중간", "latitude": 36.1, "longitude": 128.1},
            {"name": "회차지", "latitude": 36.3, "longitude": 128.3},
            {"name": "터미널", "latitude": 36.0, "longitude": 128.0},
        ]

        self.assertEqual(_turnaround_stop_name(stops, "터미널"), "회차지")

    @patch("services.bus_service.data_go_API_KEY", "SECRET-BUS-KEY")
    @patch("services.bus_service.requests.get")
    def test_bus_request_error_hides_api_key(self, mock_get):
        mock_get.side_effect = requests.ConnectionError(
            "request failed: https://example.test?serviceKey=SECRET-BUS-KEY"
        )

        try:
            get_nearby_stops(36.3, 127.3)
        except BusServiceError as error:
            caught_error = error
            formatted_error = "".join(
                traceback.format_exception(type(error), error, error.__traceback__)
            )
        else:
            self.fail("BusServiceError가 발생해야 합니다.")

        self.assertNotIn("SECRET-BUS-KEY", formatted_error)
        self.assertTrue(caught_error.__suppress_context__)

    def test_response_items_rejects_null_body(self):
        payload = {
            "response": {
                "header": {"resultCode": "00"},
                "body": None,
            }
        }

        with self.assertRaises(BusServiceError):
            _get_response_items(payload)

    @patch("services.bus_service.data_go_API_KEY", "test-key")
    @patch("services.bus_service.requests.get")
    def test_bus_request_retries_temporary_service_payload(self, mock_get):
        temporary_error = Mock()
        temporary_error.raise_for_status.return_value = None
        temporary_error.json.return_value = {"OpenAPI_ServiceResponse": {}}
        success = Mock()
        success.raise_for_status.return_value = None
        success.json.return_value = {
            "response": {
                "header": {"resultCode": "00"},
                "body": {"items": "", "totalCount": 0},
            }
        }
        mock_get.side_effect = [temporary_error, success]

        stops = get_nearby_stops(36.3, 127.3)

        self.assertEqual(stops, [])
        self.assertEqual(mock_get.call_count, 2)


    @patch("services.bus_service.data_go_API_KEY", "test-key")
    
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

    @patch("services.bus_service.data_go_API_KEY", "test-key")

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

    @patch("services.bus_service.data_go_API_KEY", "test-key")

    @patch("services.bus_service.requests.get")
    def test_get_bus_route_combines_info_and_ordered_stops(self, mock_get):
        route_response = Mock()
        route_response.raise_for_status.return_value = None
        route_response.json.return_value = {
            "response": {
                "header": {"resultCode": "00"},
                "body": {
                    "items": {
                        "item": {
                            "routeid": "DJB30300002",
                            "routeno": 2,
                            "routetp": "급행버스",
                            "startnodenm": "봉산동",
                            "endnodenm": "대전역동광장",
                            "startvehicletime": "0545",
                            "endvehicletime": 2230,
                            "intervaltime": 12,
                            "intervalsattime": 12,
                            "intervalsuntime": 16,
                        }
                    }
                },
            }
        }

        stops_response = Mock()
        stops_response.raise_for_status.return_value = None
        stops_response.json.return_value = {
            "response": {
                "header": {"resultCode": "00"},
                "body": {
                    "items": {
                        "item": [
                            {
                                "nodeid": "SECOND",
                                "nodenm": "두 번째 정류장",
                                "nodeno": 2,
                                "nodeord": 2,
                                "gpslati": 36.2,
                                "gpslong": 127.2,
                                "updowncd": 0,
                            },
                            {
                                "nodeid": "FIRST",
                                "nodenm": "첫 번째 정류장",
                                "nodeno": 1,
                                "nodeord": 1,
                                "gpslati": 36.1,
                                "gpslong": 127.1,
                                "updowncd": 0,
                            },
                        ]
                    },
                    "numOfRows": 100,
                    "pageNo": 1,
                    "totalCount": 2,
                },
            }
        }
        mock_get.side_effect = [route_response, stops_response]

        route = get_bus_route("25", "DJB30300002")

        self.assertEqual(route["first_bus_time"], "05:45")
        self.assertEqual(route["last_bus_time"], "22:30")
        self.assertEqual(
            [stop["id"] for stop in route["stops"]],
            ["FIRST", "SECOND"],
        )
        self.assertEqual(mock_get.call_count, 2)


    @patch("services.bus_service.data_go_API_KEY", "test-key")

    @patch("services.bus_service.requests.get")
    def test_get_stop_routes_converts_data(self, mock_get):
        response = Mock()
        response.raise_for_status.return_value = None
        response.json.return_value = {
            "response": {
                "header": {"resultCode": "00"},
                "body": {
                    "items": {
                        "item": [
                            {
                                "routeid": "TSB371000001",
                                "routeno": 25,
                                "routetp": "농어촌(일반)버스",
                                "startnodenm": "봉화공용터미널",
                                "endnodenm": "봉화공용터미널",
                            }
                        ]
                    },
                    "numOfRows": 100,
                    "pageNo": 1,
                    "totalCount": 1,
                },
            }
        }
        mock_get.return_value = response

        routes = get_stop_routes("37410", "TSB371000038")

        self.assertEqual(routes[0]["route_id"], "TSB371000001")
        self.assertEqual(routes[0]["bus_number"], "25")
        self.assertEqual(routes[0]["route_type"], "농어촌(일반)버스")
        self.assertEqual(mock_get.call_args.kwargs["params"]["nodeid"], "TSB371000038")
        self.assertNotIn("nodeId", mock_get.call_args.kwargs["params"])

    @patch("services.bus_service.data_go_API_KEY", "test-key")
    @patch("services.bus_service.requests.get")
    def test_get_stop_routes_includes_neighboring_city_provider(self, mock_get):
        def response(route_id, bus_number, start, end):
            result = Mock()
            result.raise_for_status.return_value = None
            result.json.return_value = {
                "response": {
                    "header": {"resultCode": "00"},
                    "body": {
                        "items": {
                            "item": {
                                "routeid": route_id,
                                "routeno": bus_number,
                                "routetp": "일반버스",
                                "startnodenm": start,
                                "endnodenm": end,
                            }
                        },
                        "totalCount": 1,
                    },
                }
            }
            return result

        mock_get.side_effect = [
            response("TSB371000049", 29, "봉화공용터미널", "영주여객차고지"),
            response("TSB356000197", 33, "삼양홈마트", "영주여객차고지"),
        ]

        routes = get_stop_routes("37410", "TSB371000047")

        self.assertEqual(
            [route["route_id"] for route in routes],
            ["TSB371000049", "TSB356000197"],
        )
        self.assertEqual(routes[0]["city_code"], "37410")
        self.assertEqual(routes[1]["city_code"], "37060")
        self.assertEqual(
            [route["bus_number"] for route in routes],
            ["33", "33"],
        )
        self.assertEqual(
            [call.kwargs["params"]["cityCode"] for call in mock_get.call_args_list],
            ["37410", "37060"],
        )


if __name__ == "__main__":
    unittest.main()
