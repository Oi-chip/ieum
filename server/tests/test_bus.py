import unittest
import traceback
from unittest.mock import Mock, patch

import requests

from app import app
from services.bus_service import (
    API_PAGE_SIZE,
    BusServiceError,
    _collect_nearby_route_candidates,
    _attach_search_arrivals,
    _destination_provider_city_codes,
    _find_destination_based_journey,
    _find_direct_journey,
    _get_all_response_items,
    _get_cached_stop_routes,
    _get_response_items,
    _load_stop_bundle,
    _load_destination_stops_for_city,
    _search_route_candidate,
    _turnaround_stop_name,
    clear_bus_route_cache,
    get_bus_arrivals,
    get_bus_route,
    get_nearby_bus_overview,
    get_nearby_stops,
    get_stop_routes,
    search_destination_stops,
    search_bus_routes,
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

    @patch("routes.bus.get_nearby_bus_overview")
    def test_nearby_bus_overview_success(self, mock_get_overview):
        mock_get_overview.return_value = {
            "stops": [{"id": "ORIGIN"}],
            "routes": [{"route_key": "37410:ROUTE"}],
            "origin_stop_count": 1,
            "route_count": 1,
            "arrival_information_unavailable": False,
            "partial": True,
            "unavailable_stop_count": 0,
            "unavailable_provider_count": 1,
        }

        response = self.client.get(
            "/api/bus/overview?latitude=36.89101&longitude=128.7331261"
        )

        data = response.get_json()
        self.assertEqual(response.status_code, 200)
        self.assertTrue(data["success"])
        self.assertEqual(data["data"]["route_count"], 1)
        self.assertTrue(data["data"]["partial"])
        mock_get_overview.assert_called_once_with(36.89101, 128.7331261)

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

    @patch("routes.bus.search_bus_routes")
    def test_bus_search_success(self, mock_search_bus_routes):
        mock_search_bus_routes.return_value = {
            "destination": "영주",
            "origin_stops": [{"id": "TSB371000047"}],
            "routes": [{
                "route_key": "37410:TSB371000049",
                "route_id": "TSB371000049",
                "bus_number": "33",
                "matched_stop": "영주여객차고지",
            }],
            "origin_stop_count": 1,
            "searched_route_count": 1,
            "route_count": 1,
            "arrival_information_unavailable": True,
            "partial": False,
            "unavailable_stop_count": 0,
            "unavailable_provider_count": 0,
            "unavailable_route_count": 0,
            "incomplete_result_count": 0,
        }

        response = self.client.get(
            "/api/bus/search",
            query_string={
                "latitude": "36.89101",
                "longitude": "128.7331261",
                "destination": "영주",
                "origin_stop_id": "TSB371000047",
                "origin_city_code": "37410",
            },
        )

        data = response.get_json()
        self.assertEqual(response.status_code, 200)
        self.assertTrue(data["success"])
        self.assertEqual(data["data"]["routes"][0]["bus_number"], "33")
        mock_search_bus_routes.assert_called_once_with(
            36.89101,
            128.7331261,
            "영주",
            "TSB371000047",
            "37410",
            None,
            None,
        )

    @patch("routes.bus.search_destination_stops")
    def test_destination_stop_search_success(self, mock_search_stops):
        mock_search_stops.return_value = {
            "destination": "영주",
            "stops": [{
                "id": "TSB356000008",
                "city_code": "37060",
                "name": "영주역",
            }],
            "searched_city_codes": ["37060"],
            "partial": False,
            "unavailable_city_codes": [],
        }

        response = self.client.get(
            "/api/bus/destination-stops",
            query_string={
                "latitude": "36.89101",
                "longitude": "128.7331261",
                "destination": "영주",
            },
        )

        data = response.get_json()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(data["data"]["stops"][0]["name"], "영주역")
        mock_search_stops.assert_called_once_with(
            36.89101,
            128.7331261,
            "영주",
        )

    @patch("routes.bus.search_bus_routes")
    def test_bus_search_passes_selected_destination_stop(self, mock_search):
        mock_search.return_value = {
            "destination": "영주",
            "routes": [],
        }

        response = self.client.get(
            "/api/bus/search",
            query_string={
                "latitude": "36.89101",
                "longitude": "128.7331261",
                "destination": "영주",
                "destination_stop_id": "TSB356000008",
                "destination_city_code": "37060",
            },
        )

        self.assertEqual(response.status_code, 200)
        mock_search.assert_called_once_with(
            36.89101,
            128.7331261,
            "영주",
            None,
            None,
            "TSB356000008",
            "37060",
        )

    @patch("routes.bus.search_bus_routes")
    def test_bus_search_validates_destination_and_origin(self, mock_search):
        cases = [
            ({
                "latitude": "36.89101",
                "longitude": "128.7331261",
            }, "MISSING_DESTINATION"),
            ({
                "latitude": "36.89101",
                "longitude": "128.7331261",
                "destination": "영" * 81,
            }, "INVALID_DESTINATION"),
            ({
                "latitude": "36.89101",
                "longitude": "128.7331261",
                "destination": "---",
            }, "INVALID_DESTINATION"),
            ({
                "latitude": "36.89101",
                "longitude": "128.7331261",
                "destination": "영주",
                "origin_stop_id": "TSB371000047",
            }, "INVALID_ORIGIN_STOP"),
            ({
                "latitude": "36.89101",
                "longitude": "128.7331261",
                "destination": "영주",
                "origin_city_code": "37410",
            }, "INVALID_ORIGIN_STOP"),
            ({
                "latitude": "36.89101",
                "longitude": "128.7331261",
                "destination": "영주",
                "origin_stop_id": "invalid-stop-id",
                "origin_city_code": "37410",
            }, "INVALID_ORIGIN_STOP"),
            ({
                "latitude": "36.89101",
                "longitude": "128.7331261",
                "destination": "영주",
                "origin_stop_id": "TSB371000047",
                "origin_city_code": "invalid",
            }, "INVALID_ORIGIN_STOP"),
            ({
                "latitude": "36.89101",
                "longitude": "128.7331261",
                "destination": "영주",
                "destination_stop_id": "TSB356000008",
            }, "INVALID_DESTINATION_STOP"),
            ({
                "latitude": "36.89101",
                "longitude": "128.7331261",
                "destination": "영주",
                "destination_stop_id": "invalid-stop-id",
                "destination_city_code": "37060",
            }, "INVALID_DESTINATION_STOP"),
        ]

        for query, error_code in cases:
            with self.subTest(error_code=error_code, query=query):
                response = self.client.get(
                    "/api/bus/search",
                    query_string=query,
                )
                self.assertEqual(response.status_code, 400)
                self.assertEqual(
                    response.get_json()["error"]["code"],
                    error_code,
                )

        mock_search.assert_not_called()


class BusServiceTest(unittest.TestCase):
    def setUp(self):
        clear_bus_route_cache()

    def tearDown(self):
        clear_bus_route_cache()

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

    @patch("services.bus_service._request_bus_api")
    def test_get_all_response_items_reads_every_page(self, mock_request):
        first_page = [{"id": f"ITEM-{index}"} for index in range(API_PAGE_SIZE)]
        second_page = [{"id": "ITEM-LAST"}]

        def payload(items):
            return {
                "response": {
                    "header": {"resultCode": "00"},
                    "body": {
                        "items": {"item": items},
                        "totalCount": API_PAGE_SIZE + 1,
                    },
                }
            }

        mock_request.side_effect = [payload(first_page), payload(second_page)]

        items = _get_all_response_items(
            "https://example.test/bus",
            {"cityCode": "25"},
        )

        self.assertEqual(len(items), API_PAGE_SIZE + 1)
        self.assertEqual(items[-1]["id"], "ITEM-LAST")
        self.assertEqual(
            [request.args[1]["pageNo"] for request in mock_request.call_args_list],
            [1, 2],
        )
        self.assertTrue(all(
            request.args[1]["numOfRows"] == API_PAGE_SIZE
            for request in mock_request.call_args_list
        ))

    @patch("services.bus_service._request_bus_api")
    def test_get_all_response_items_rejects_empty_page_before_total(
        self,
        mock_request,
    ):
        def payload(items):
            return {
                "response": {
                    "header": {"resultCode": "00"},
                    "body": {
                        "items": {"item": items},
                        "totalCount": 2,
                    },
                }
            }

        mock_request.side_effect = [
            payload([{"id": "ITEM-1"}]),
            payload([]),
        ]

        with self.assertRaises(BusServiceError):
            _get_all_response_items("https://example.test/bus", {})

        self.assertEqual(mock_request.call_count, 2)

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

    @patch("services.bus_service._get_all_response_items")
    def test_destination_stop_loader_uses_name_search_api(self, mock_get_items):
        mock_get_items.return_value = [{
            "nodeid": "TSB356000008",
            "citycode": "37060",
            "nodenm": "영주역",
            "nodeno": "3560008",
            "gpslati": 36.810486,
            "gpslong": 128.624387,
        }]

        stops = _load_destination_stops_for_city("37060", "영주")

        self.assertEqual(stops[0]["name"], "영주역")
        self.assertIn("getSttnNoList", mock_get_items.call_args.args[0])
        self.assertEqual(
            mock_get_items.call_args.args[1],
            {"cityCode": "37060", "nodeNm": "영주"},
        )

    @patch("services.bus_service._get_cached_destination_stops")
    @patch("services.bus_service._get_cached_nearby_stops")
    @patch(
        "services.bus_service._destination_provider_city_codes",
        return_value=("37060",),
    )
    def test_destination_stop_search_uses_destination_and_origin_city_codes(
        self,
        _mock_destination_codes,
        mock_nearby_stops,
        mock_destination_stops,
    ):
        mock_nearby_stops.return_value = [{"city_code": "37410"}]

        def stops_for_city(city_code, _destination):
            if city_code != "37060":
                return []
            return [{
                "id": "TSB356000008",
                "city_code": "37060",
                "name": "영주역",
                "number": "3560008",
                "latitude": 36.810486,
                "longitude": 128.624387,
            }]

        mock_destination_stops.side_effect = stops_for_city

        result = search_destination_stops(
            36.89101,
            128.7331261,
            "영주",
        )

        self.assertEqual(result["stops"][0]["id"], "TSB356000008")
        self.assertEqual(result["searched_city_codes"], ["37060", "37410"])
        self.assertEqual(
            {call.args[0] for call in mock_destination_stops.call_args_list},
            {"37060", "37410"},
        )

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

    @patch("services.bus_service._get_route_stops")
    @patch("services.bus_service._get_route_info")
    def test_get_bus_route_returns_stops_when_info_is_unavailable(
        self,
        mock_get_route_info,
        mock_get_route_stops,
    ):
        mock_get_route_info.side_effect = BusServiceError("info unavailable")
        mock_get_route_stops.return_value = [{
            "id": "STOP-1",
            "name": "출발 정류장",
            "number": "1",
            "order": 1,
            "latitude": 36.8,
            "longitude": 128.7,
            "direction_code": "2",
        }]

        route = get_bus_route("37410", "ROUTE-1")

        self.assertEqual(route["id"], "ROUTE-1")
        self.assertEqual(route["stops"][0]["id"], "STOP-1")
        self.assertFalse(route["data_complete"])
        self.assertEqual(route["unavailable_fields"], ["route_info"])

    @patch("services.bus_service._get_route_stops")
    @patch("services.bus_service._get_route_info")
    def test_get_bus_route_returns_info_when_stops_are_unavailable(
        self,
        mock_get_route_info,
        mock_get_route_stops,
    ):
        mock_get_route_info.return_value = {
            "routeid": "ROUTE-2",
            "routeno": "33",
            "routetp": "일반버스",
            "startnodenm": "봉화",
            "endnodenm": "영주",
            "startvehicletime": "0600",
            "endvehicletime": "2200",
            "intervaltime": "30",
        }
        mock_get_route_stops.side_effect = BusServiceError("stops unavailable")

        route = get_bus_route("37410", "ROUTE-2")

        self.assertEqual(route["number"], "33")
        self.assertEqual(route["first_bus_time"], "06:00")
        self.assertEqual(route["stops"], [])
        self.assertFalse(route["data_complete"])
        self.assertEqual(route["unavailable_fields"], ["route_stops"])


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

    @patch("services.bus_service._get_route_info")
    @patch("services.bus_service._get_route_stops")
    def test_search_route_candidate_uses_second_nearby_boarding_stop(
        self,
        mock_get_route_stops,
        mock_get_route_info,
    ):
        first_stop = {
            "id": "FIRST-NEARBY",
            "city_code": "37410",
            "name": "첫 번째 정류장",
            "number": "100",
            "latitude": 36.891,
            "longitude": 128.733,
            "distance_m": 10,
        }
        second_stop = {
            "id": "SECOND-NEARBY",
            "city_code": "37410",
            "name": "두 번째 정류장",
            "number": "200",
            "latitude": 36.892,
            "longitude": 128.734,
            "distance_m": 200,
        }
        mock_get_route_stops.return_value = [
            {
                "id": "SECOND-NEARBY",
                "name": "두 번째 정류장",
                "number": "200",
                "order": 1,
                "latitude": 36.892,
                "longitude": 128.734,
                "direction_code": "2",
            },
            {
                "id": "DESTINATION",
                "name": "영주여객차고지",
                "number": "300",
                "order": 2,
                "latitude": 36.805,
                "longitude": 128.624,
                "direction_code": "2",
            },
        ]
        mock_get_route_info.return_value = {
            "routeid": "ROUTE-33",
            "routeno": "33",
            "routetp": "일반버스",
            "startnodenm": "봉화",
            "endnodenm": "영주",
        }
        candidate = {
            "route": {
                "route_id": "ROUTE-33",
                "city_code": "37410",
                "bus_number": "33",
                "api_bus_number": "33",
                "route_type": "일반버스",
                "start_stop": "봉화",
                "end_stop": "영주",
            },
            "boardings": [
                {"stop": first_stop, "arrival": None},
                {"stop": second_stop, "arrival": None},
            ],
        }

        result, incomplete = _search_route_candidate(candidate, "영주")

        self.assertFalse(incomplete)
        self.assertEqual(result["boarding_stop"]["id"], "SECOND-NEARBY")
        self.assertEqual(result["destination_stop"]["id"], "DESTINATION")
        self.assertEqual(result["boarding_order"], 1)
        self.assertEqual(result["destination_order"], 2)

    def test_find_direct_journey_excludes_destination_before_boarding(self):
        route_stops = [
            {
                "id": "DESTINATION",
                "name": "영주여객차고지",
                "number": "300",
                "order": 1,
            },
            {
                "id": "ORIGIN",
                "name": "봉화군청",
                "number": "100",
                "order": 2,
            },
        ]
        boardings = [{
            "stop": {
                "id": "ORIGIN",
                "name": "봉화군청",
                "number": "100",
                "distance_m": 0,
            },
            "arrival": None,
        }]

        journey = _find_direct_journey(route_stops, boardings, "영주")

        self.assertIsNone(journey)

    def test_destination_based_journey_is_not_limited_to_500_meters(self):
        route_stops = [
            {
                "id": "FAR-BOARDING",
                "name": "승차 정류장",
                "number": "100",
                "order": 1,
                "latitude": 36.9005,
                "longitude": 128.733,
            },
            {
                "id": "DESTINATION",
                "name": "영주역",
                "number": "200",
                "order": 2,
                "latitude": 36.810486,
                "longitude": 128.624387,
            },
        ]

        journey = _find_destination_based_journey(
            route_stops,
            36.891,
            128.733,
            {"id": "DESTINATION"},
        )

        self.assertIsNotNone(journey)
        self.assertGreater(journey["boarding"]["stop"]["distance_m"], 500)
        self.assertEqual(journey["boarding_stop"]["id"], "FAR-BOARDING")
        self.assertEqual(journey["destination_stop"]["id"], "DESTINATION")

    def test_find_direct_journey_checks_every_duplicate_origin_occurrence(self):
        route_stops = [
            {"id": "ORIGIN", "name": "순환 출발", "number": "100", "order": 1},
            {"id": "MIDDLE", "name": "중간 1", "number": "101", "order": 2},
            {"id": "MIDDLE-2", "name": "중간 2", "number": "102", "order": 3},
            {"id": "ORIGIN", "name": "순환 출발", "number": "100", "order": 4},
            {"id": "DESTINATION", "name": "영주역", "number": "200", "order": 5},
        ]
        boardings = [{
            "stop": {
                "id": "ORIGIN",
                "name": "순환 출발",
                "number": "100",
                "distance_m": 30,
            },
            "arrival": None,
        }]

        journey = _find_direct_journey(route_stops, boardings, "영주")

        self.assertIsNotNone(journey)
        self.assertEqual(journey["boarding_stop"]["order"], 4)
        self.assertEqual(journey["destination_stop"]["order"], 5)
        self.assertEqual(journey["stops_between"], 1)

    def test_find_direct_journey_does_not_board_opposite_same_name_stop(self):
        route_stops = [
            {
                "id": "OPPOSITE",
                "name": "중앙시장",
                "number": "101",
                "order": 1,
                "latitude": 36.0005,
                "longitude": 128.0,
            },
            {
                "id": "DESTINATION",
                "name": "영주역",
                "number": "200",
                "order": 2,
                "latitude": 36.1,
                "longitude": 128.1,
            },
            {
                "id": "SELECTED",
                "name": "중앙시장",
                "number": "100",
                "order": 3,
                "latitude": 36.0,
                "longitude": 128.0,
            },
        ]
        boardings = [{
            "stop": {
                "id": "SELECTED",
                "name": "중앙시장",
                "number": "100",
                "latitude": 36.0,
                "longitude": 128.0,
                "distance_m": 20,
            },
            "arrival": None,
        }]

        journey = _find_direct_journey(route_stops, boardings, "영주")

        self.assertIsNone(journey)

    @patch("services.bus_service._get_route_info")
    @patch("services.bus_service._get_route_stops")
    def test_search_route_candidate_does_not_treat_bus_number_as_destination(
        self,
        mock_get_route_stops,
        mock_get_route_info,
    ):
        mock_get_route_stops.return_value = [
            {
                "id": "ORIGIN",
                "name": "봉화군청",
                "number": "100",
                "order": 1,
            },
            {
                "id": "TERMINUS",
                "name": "춘양터미널",
                "number": "200",
                "order": 2,
            },
        ]
        candidate = {
            "route": {
                "route_id": "ROUTE-33",
                "city_code": "37410",
                "bus_number": "33",
                "api_bus_number": "33",
                "route_type": "일반버스",
                "start_stop": "봉화",
                "end_stop": "춘양",
            },
            "boardings": [{
                "stop": {
                    "id": "ORIGIN",
                    "name": "봉화군청",
                    "number": "100",
                    "distance_m": 0,
                },
                "arrival": None,
            }],
        }

        result, incomplete = _search_route_candidate(candidate, "33")

        self.assertIsNone(result)
        self.assertFalse(incomplete)
        mock_get_route_info.assert_not_called()

    @patch("services.bus_service._load_stop_bundle")
    @patch("services.bus_service.get_nearby_stops")
    def test_collect_candidates_preserves_composite_route_key(
        self,
        mock_get_nearby_stops,
        mock_load_stop_bundle,
    ):
        stop = {
            "id": "ORIGIN",
            "city_code": "37410",
            "name": "봉화군청",
            "number": "100",
            "latitude": 36.891,
            "longitude": 128.733,
            "distance_m": 0,
        }
        routes = [
            {
                "route_id": "SHARED-ID",
                "city_code": "37410",
                "bus_number": "33",
            },
            {
                "route_id": "SHARED-ID",
                "city_code": "37060",
                "bus_number": "533",
            },
        ]
        mock_get_nearby_stops.return_value = [stop]
        mock_load_stop_bundle.return_value = {
            "stop": stop,
            "routes": routes,
            "arrivals": {},
            "route_error": False,
            "arrival_error": True,
            "unavailable_provider_codes": ["37060"],
        }

        collected = _collect_nearby_route_candidates(36.891, 128.733)

        self.assertEqual(
            set(collected["candidates"]),
            {("37410", "SHARED-ID"), ("37060", "SHARED-ID")},
        )
        self.assertEqual(collected["unavailable_provider_count"], 1)
        self.assertTrue(collected["arrival_information_unavailable"])

    @patch("services.bus_service._collect_nearby_route_candidates")
    def test_overview_marks_partial_arrival_provider_failures(self, mock_collect):
        stop = {"id": "STOP-1", "distance_m": 10}
        route = {
            "route_id": "ROUTE-1",
            "city_code": "37410",
            "bus_number": "1",
        }
        mock_collect.return_value = {
            "nearby_stops": [stop],
            "origin_stops": [stop],
            "candidates": {
                ("37410", "ROUTE-1"): {
                    "route": route,
                    "boardings": [{"stop": stop, "arrival": None}],
                },
            },
            "unavailable_stop_count": 0,
            "unavailable_provider_count": 0,
            "unavailable_arrival_provider_count": 1,
            "arrival_information_unavailable": False,
        }

        overview = get_nearby_bus_overview(36.891, 128.733)

        self.assertTrue(overview["partial"])
        self.assertEqual(overview["route_count"], 1)
        self.assertEqual(overview["unavailable_arrival_provider_count"], 1)
        self.assertFalse(overview["arrival_information_unavailable"])

    @patch("services.bus_service._load_stop_routes_for_provider")
    def test_successful_stop_route_provider_is_cached_while_failed_retries(
        self,
        mock_load_provider_routes,
    ):
        local_route = {
            "route_id": "ROUTE-1",
            "city_code": "37410",
            "bus_number": "1",
        }
        neighboring_route = {
            "route_id": "ROUTE-2",
            "city_code": "37060",
            "bus_number": "2",
        }
        neighboring_attempts = 0

        def load_routes(provider_city_code, _stop_id):
            nonlocal neighboring_attempts
            if provider_city_code == "37410":
                return [local_route]
            neighboring_attempts += 1
            if neighboring_attempts == 1:
                raise BusServiceError("temporary provider failure")
            return [neighboring_route]

        mock_load_provider_routes.side_effect = load_routes

        first = _get_cached_stop_routes("37410", "STOP-1")
        second = _get_cached_stop_routes("37410", "STOP-1")

        self.assertEqual(first[1], ["37060"])
        self.assertEqual(first[0], [local_route])
        self.assertEqual(len(second[0]), 2)
        self.assertEqual(second[1], [])
        self.assertEqual(
            [call.args[0] for call in mock_load_provider_routes.call_args_list],
            ["37410", "37060", "37060"],
        )

    @patch("services.bus_service._load_stop_routes_for_provider")
    def test_expanding_provider_candidates_reuses_existing_provider_cache(
        self,
        mock_load_provider_routes,
    ):
        def load_routes(provider_city_code, _stop_id):
            return [{
                "route_id": f"ROUTE-{provider_city_code}",
                "city_code": provider_city_code,
                "bus_number": "1",
            }]

        mock_load_provider_routes.side_effect = load_routes

        _get_cached_stop_routes("37410", "STOP-1")
        routes, unavailable = _get_cached_stop_routes(
            "37410",
            "STOP-1",
            ("99999",),
        )

        self.assertEqual(len(routes), 3)
        self.assertEqual(unavailable, [])
        self.assertEqual(
            [call.args[0] for call in mock_load_provider_routes.call_args_list],
            ["37410", "37060", "99999"],
        )

    @patch("services.bus_service._get_city_codes")
    def test_destination_city_name_adds_provider_candidate(self, mock_get_codes):
        mock_get_codes.return_value = [
            {"code": "37060", "name": "영주시"},
            {"code": "37410", "name": "봉화군"},
            {"code": "99999", "name": "구"},
            {"code": "25", "name": "대전광역시/계룡시"},
            {"code": "32020", "name": "원주시/횡성군"},
        ]

        self.assertEqual(
            _destination_provider_city_codes("영주"),
            ("37060",),
        )
        self.assertEqual(
            _destination_provider_city_codes("영주역"),
            ("37060",),
        )
        self.assertEqual(
            _destination_provider_city_codes("영주시청"),
            ("37060",),
        )
        self.assertEqual(_destination_provider_city_codes("남영주역"), ())
        self.assertEqual(_destination_provider_city_codes("구청"), ())
        self.assertEqual(_destination_provider_city_codes("대전"), ("25",))
        self.assertEqual(_destination_provider_city_codes("계룡"), ("25",))
        self.assertEqual(_destination_provider_city_codes("계룡역"), ("25",))
        self.assertEqual(_destination_provider_city_codes("원주"), ("32020",))
        self.assertEqual(_destination_provider_city_codes("횡성"), ("32020",))

    @patch("services.bus_service._get_cached_arrivals")
    @patch("services.bus_service._get_cached_stop_routes")
    def test_load_stop_bundle_matches_arrivals_by_composite_route_key(
        self,
        mock_get_routes,
        mock_get_arrivals,
    ):
        stop = {"id": "STOP-1", "city_code": "37410"}
        mock_get_routes.return_value = ([
            {
                "route_id": "SHARED-ID",
                "city_code": "37410",
                "bus_number": "33",
            },
            {
                "route_id": "SHARED-ID",
                "city_code": "37060",
                "bus_number": "533",
            },
        ], [])

        def arrivals_for(city_code, _stop_id):
            return [{
                "route_id": "SHARED-ID",
                "arrival_seconds": 60 if city_code == "37410" else 300,
            }]

        mock_get_arrivals.side_effect = arrivals_for

        bundle = _load_stop_bundle(stop)

        self.assertEqual(
            bundle["arrivals"][("37410", "SHARED-ID")]["arrival_seconds"],
            60,
        )
        self.assertEqual(
            bundle["arrivals"][("37060", "SHARED-ID")]["arrival_seconds"],
            300,
        )
        self.assertEqual(mock_get_arrivals.call_count, 2)

    @patch("services.bus_service._get_cached_arrivals")
    def test_search_arrivals_use_route_provider_city_code(
        self,
        mock_get_arrivals,
    ):
        boarding_stop = {
            "id": "STOP-1",
            "city_code": "37410",
            "distance_m": 10,
        }
        results = [
            {
                "route_id": "SHARED-ID",
                "city_code": "37410",
                "boarding_stop": boarding_stop,
            },
            {
                "route_id": "SHARED-ID",
                "city_code": "37060",
                "boarding_stop": boarding_stop,
            },
        ]

        def arrivals_for(city_code, _stop_id):
            seconds = 60 if city_code == "37410" else 300
            return [{
                "route_id": "SHARED-ID",
                "remaining_stops": 1,
                "arrival_seconds": seconds,
                "arrival_minutes": seconds // 60,
                "vehicle_type": None,
            }]

        mock_get_arrivals.side_effect = arrivals_for

        unavailable_count = _attach_search_arrivals(results)

        self.assertEqual(unavailable_count, 0)
        self.assertEqual(results[0]["arrival_minutes"], 1)
        self.assertEqual(results[1]["arrival_minutes"], 5)

    @patch("services.bus_service._get_route_info")
    @patch("services.bus_service._get_route_stops", return_value=[])
    def test_empty_route_stops_mark_summary_match_incomplete(
        self,
        _mock_get_stops,
        mock_get_info,
    ):
        mock_get_info.return_value = {
            "routeid": "ROUTE-1",
            "routeno": "1",
            "endnodenm": "Destination",
        }
        candidate = {
            "route": {
                "route_id": "ROUTE-1",
                "city_code": "37410",
                "bus_number": "1",
                "api_bus_number": "1",
                "route_type": None,
                "start_stop": "Origin",
                "end_stop": "Destination",
            },
            "boardings": [{
                "stop": {"id": "STOP-1", "distance_m": 10},
                "arrival": None,
            }],
        }

        result, incomplete = _search_route_candidate(candidate, "Destination")

        self.assertIsNotNone(result)
        self.assertTrue(incomplete)
        self.assertFalse(result["data_complete"])
        self.assertIn("route_stops", result["unavailable_fields"])

    @patch(
        "services.bus_service._destination_provider_city_codes",
        return_value=("37060",),
    )
    @patch("services.bus_service._attach_search_arrivals", return_value=2)
    @patch("services.bus_service._search_route_candidate")
    @patch("services.bus_service._collect_nearby_route_candidates")
    def test_search_bus_routes_preserves_composite_routes_and_partial_metadata(
        self,
        mock_collect,
        mock_search_candidate,
        mock_attach_arrivals,
        mock_destination_providers,
    ):
        stop = {"id": "ORIGIN", "distance_m": 0}
        candidates = {
            ("37410", "SHARED-ID"): {
                "route": {
                    "route_id": "SHARED-ID",
                    "city_code": "37410",
                    "bus_number": "33",
                },
                "boardings": [],
            },
            ("37060", "SHARED-ID"): {
                "route": {
                    "route_id": "SHARED-ID",
                    "city_code": "37060",
                    "bus_number": "533",
                },
                "boardings": [],
            },
        }
        mock_collect.return_value = {
            "nearby_stops": [stop],
            "origin_stops": [stop],
            "bundles": [],
            "candidates": candidates,
            "unavailable_stop_count": 1,
            "unavailable_provider_count": 2,
            "arrival_information_unavailable": True,
        }

        def result_for(candidate, _destination):
            route = candidate["route"]
            city_code = route["city_code"]
            return ({
                "route_id": route["route_id"],
                "city_code": city_code,
                "route_key": f'{city_code}:{route["route_id"]}',
                "boarding_stop": {
                    "id": "ORIGIN",
                    "city_code": "37410",
                    "distance_m": 0,
                },
                "stops_between": 1,
                "arrival_minutes": None,
                "bus_number": route["bus_number"],
            }, city_code == "37060")

        mock_search_candidate.side_effect = result_for

        result = search_bus_routes(36.891, 128.733, "영주")

        self.assertEqual(
            {route["route_key"] for route in result["routes"]},
            {"37410:SHARED-ID", "37060:SHARED-ID"},
        )
        self.assertEqual(result["route_count"], 2)
        self.assertEqual(result["searched_route_count"], 2)
        self.assertTrue(result["partial"])
        self.assertEqual(result["unavailable_stop_count"], 1)
        self.assertEqual(result["unavailable_provider_count"], 2)
        self.assertEqual(result["incomplete_result_count"], 1)
        self.assertEqual(result["unavailable_arrival_stop_count"], 2)
        self.assertTrue(result["arrival_information_unavailable"])
        self.assertEqual(result["destination_provider_city_codes"], ["37060"])
        self.assertFalse(result["provider_discovery_unavailable"])
        self.assertEqual(mock_collect.call_args.args[-1], ("37060",))
        mock_destination_providers.assert_called_once_with("영주")
        mock_attach_arrivals.assert_called_once()

    @patch("services.bus_service._attach_search_arrivals", return_value=0)
    @patch("services.bus_service._search_destination_route_candidate")
    @patch("services.bus_service._get_cached_stop_routes")
    @patch("services.bus_service._get_cached_nearby_stops", return_value=[])
    def test_selected_destination_stop_uses_reverse_route_search_without_radius(
        self,
        _mock_nearby_stops,
        mock_stop_routes,
        mock_search_candidate,
        _mock_attach_arrivals,
    ):
        route = {
            "route_id": "ROUTE-33",
            "city_code": "37060",
            "bus_number": "33",
        }
        mock_stop_routes.return_value = ([route], [])
        mock_search_candidate.return_value = ({
            "route_id": "ROUTE-33",
            "city_code": "37060",
            "route_key": "37060:ROUTE-33",
            "bus_number": "33",
            "boarding_stop": {
                "id": "BOARDING",
                "city_code": "37060",
                "name": "승차 정류장",
                "distance_m": 850,
            },
            "destination_stop": {
                "id": "DESTINATION",
                "name": "영주역",
            },
            "stops_between": 4,
            "arrival_minutes": None,
        }, False)

        result = search_bus_routes(
            36.891,
            128.733,
            "영주",
            destination_stop_id="DESTINATION",
            destination_city_code="37060",
        )

        self.assertEqual(result["search_mode"], "destination_stop")
        self.assertIsNone(result["origin_search_radius_m"])
        self.assertEqual(result["routes"][0]["boarding_stop"]["distance_m"], 850)
        self.assertEqual(result["route_count"], 1)


if __name__ == "__main__":
    unittest.main()
