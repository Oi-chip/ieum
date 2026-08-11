import traceback
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import Mock, patch

import requests

from app import app
from services.hospital_service import (
    HospitalConfigurationError,
    HospitalServiceError,
    _parse_hospital_response,
    get_nearby_hospitals,
    search_hospitals,
)


KOREA_TIMEZONE = timezone(timedelta(hours=9))
MONDAY_10_AM = datetime(2026, 8, 10, 10, 0, tzinfo=KOREA_TIMEZONE)
MONDAY_6_PM = datetime(2026, 8, 10, 18, 0, tzinfo=KOREA_TIMEZONE)
SUNDAY_NOON = datetime(2026, 8, 16, 12, 0, tzinfo=KOREA_TIMEZONE)

SAMPLE_XML = """<?xml version="1.0" encoding="UTF-8"?>
<response>
  <header>
    <resultCode>00</resultCode>
    <resultMsg>NORMAL SERVICE.</resultMsg>
  </header>
  <body>
    <items>
      <item>
        <hpid>FAR-HOSPITAL</hpid>
        <dutyName>먼 병원</dutyName>
        <dutyDivNam>병원</dutyDivNam>
        <dutyAddr>경상북도 봉화군 먼길 2</dutyAddr>
        <dutyTel1>054-000-0002</dutyTel1>
        <dutyTime1s>0900</dutyTime1s>
        <dutyTime1c>1800</dutyTime1c>
        <dutyEryn>1</dutyEryn>
        <dutyEmclsName>지역응급의료기관</dutyEmclsName>
        <postCdn1>362</postCdn1>
        <postCdn2>01</postCdn2>
        <wgs84Lat>36.903633</wgs84Lat>
        <wgs84Lon>128.7412033</wgs84Lon>
      </item>
      <item>
        <hpid>NEAR-HOSPITAL</hpid>
        <dutyName>가까운 병원</dutyName>
        <dutyDivNam>의원</dutyDivNam>
        <dutyAddr>경상북도 봉화군 가까운길 1</dutyAddr>
        <dutyTel1>054-000-0001</dutyTel1>
        <dutyTime1s>0900</dutyTime1s>
        <dutyTime1c>1700</dutyTime1c>
        <dutyTime6s>0830</dutyTime6s>
        <dutyTime6c>1200</dutyTime6c>
        <dutyEryn>2</dutyEryn>
        <dutyEmclsName>응급의료기관 이외</dutyEmclsName>
        <postCdn1>362</postCdn1>
        <postCdn2>39</postCdn2>
        <wgs84Lat>36.893733</wgs84Lat>
        <wgs84Lon>128.7313033</wgs84Lon>
      </item>
    </items>
    <numOfRows>1000</numOfRows>
    <pageNo>1</pageNo>
    <totalCount>2</totalCount>
  </body>
</response>
""".encode("utf-8")


class HospitalRouteTest(unittest.TestCase):
    def setUp(self):
        app.config["TESTING"] = True
        self.client = app.test_client()

    @patch("routes.hospital.get_nearby_hospitals")
    def test_nearby_hospitals_success(self, mock_get_nearby_hospitals):
        mock_get_nearby_hospitals.return_value = [{
            "id": "NEAR-HOSPITAL",
            "name": "가까운 병원",
            "distance_m": 14,
            "is_open": True,
            "today_hours": "09:00~17:00",
        }]

        response = self.client.get(
            "/api/hospitals/nearby?latitude=36.893633&longitude=128.7312033"
            "&sido=경상북도&sigungu=봉화군"
        )

        data = response.get_json()
        self.assertEqual(response.status_code, 200)
        self.assertTrue(data["success"])
        self.assertEqual(data["data"]["hospitals"][0]["id"], "NEAR-HOSPITAL")

    def test_nearby_hospitals_requires_both_coordinates(self):
        response = self.client.get(
            "/api/hospitals/nearby?latitude=36.893633"
            "&sido=경상북도&sigungu=봉화군"
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json()["error"]["code"], "MISSING_LOCATION")

    def test_nearby_hospitals_requires_region(self):
        response = self.client.get(
            "/api/hospitals/nearby?latitude=36.893633&longitude=128.7312033"
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json()["error"]["code"], "MISSING_REGION")

    def test_nearby_hospitals_rejects_invalid_radius(self):
        response = self.client.get(
            "/api/hospitals/nearby?latitude=36.893633&longitude=128.7312033"
            "&sido=경상북도&sigungu=봉화군&radius_m=60000"
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json()["error"]["code"], "INVALID_RADIUS")

    @patch("routes.hospital.get_nearby_hospitals")
    def test_nearby_hospitals_handles_missing_key(self, mock_get_nearby_hospitals):
        mock_get_nearby_hospitals.side_effect = HospitalConfigurationError()

        response = self.client.get(
            "/api/hospitals/nearby?latitude=36.893633&longitude=128.7312033"
            "&sido=경상북도&sigungu=봉화군"
        )

        self.assertEqual(response.status_code, 500)
        self.assertEqual(
            response.get_json()["error"]["code"],
            "HOSPITAL_API_KEY_MISSING",
        )

    @patch("routes.hospital.get_nearby_hospitals")
    def test_nearby_hospitals_handles_external_error(self, mock_get_nearby_hospitals):
        mock_get_nearby_hospitals.side_effect = HospitalServiceError()

        response = self.client.get(
            "/api/hospitals/nearby?latitude=36.893633&longitude=128.7312033"
            "&sido=경상북도&sigungu=봉화군"
        )

        self.assertEqual(response.status_code, 502)
        self.assertEqual(
            response.get_json()["error"]["code"],
            "HOSPITAL_DATA_UNAVAILABLE",
        )

    def test_hospital_search_requires_keyword(self):
        response = self.client.get("/api/hospitals/search")

        self.assertEqual(response.status_code, 400)
        self.assertEqual(
            response.get_json()["error"]["code"],
            "MISSING_HOSPITAL_QUERY",
        )

    def test_hospital_search_location_requires_region(self):
        response = self.client.get(
            "/api/hospitals/search?keyword=병원"
            "&latitude=36.893633&longitude=128.7312033"
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.get_json()["error"]["code"], "MISSING_REGION")

    @patch("routes.hospital.search_hospitals")
    def test_hospital_search_success(self, mock_search_hospitals):
        mock_search_hospitals.return_value = []

        response = self.client.get(
            "/api/hospitals/search?keyword=봉화병원&limit=5"
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["data"]["hospitals"], [])
        mock_search_hospitals.assert_called_once_with(
            "봉화병원",
            latitude=None,
            longitude=None,
            sido=None,
            sigungu=None,
            radius_m=20000,
            limit=5,
        )


class HospitalServiceTest(unittest.TestCase):
    @patch("services.hospital_service.DATA_GO_KR_API_KEY", "SECRET-HOSPITAL-KEY")
    @patch("services.hospital_service.requests.get")
    def test_hospital_request_error_hides_api_key(self, mock_get):
        mock_get.side_effect = requests.ConnectionError(
            "request failed: https://example.test?serviceKey=SECRET-HOSPITAL-KEY"
        )

        try:
            get_nearby_hospitals(
                36.893633,
                128.7312033,
                "경상북도",
                "봉화군",
            )
        except HospitalServiceError as error:
            caught_error = error
            formatted_error = "".join(
                traceback.format_exception(type(error), error, error.__traceback__)
            )
        else:
            self.fail("HospitalServiceError가 발생해야 합니다.")

        self.assertNotIn("SECRET-HOSPITAL-KEY", formatted_error)
        self.assertTrue(caught_error.__suppress_context__)

    @patch("services.hospital_service.DATA_GO_KR_API_KEY", "test-key")
    @patch("services.hospital_service.requests.get")
    def test_nearby_hospitals_converts_sorts_and_calculates_open_status(self, mock_get):
        response = Mock()
        response.raise_for_status.return_value = None
        response.content = SAMPLE_XML
        mock_get.return_value = response

        hospitals = get_nearby_hospitals(
            36.893633,
            128.7312033,
            "경상북도",
            "봉화군",
            radius_m=5000,
            now=MONDAY_10_AM,
        )

        self.assertEqual(
            [hospital["id"] for hospital in hospitals],
            ["NEAR-HOSPITAL", "FAR-HOSPITAL"],
        )
        self.assertEqual(hospitals[0]["type"], "의원")
        self.assertEqual(hospitals[0]["phone"], "054-000-0001")
        self.assertTrue(hospitals[0]["is_open"])
        self.assertEqual(hospitals[0]["open_status"], "open")
        self.assertEqual(hospitals[0]["today_hours"], "09:00~17:00")
        self.assertEqual(hospitals[0]["weekly_hours"]["saturday"], "08:30~12:00")
        self.assertFalse(hospitals[0]["has_emergency_room"])
        params = mock_get.call_args.kwargs["params"]
        self.assertEqual(params["Q0"], "경상북도")
        self.assertEqual(params["Q1"], "봉화군")
        self.assertEqual(params["serviceKey"], "test-key")

    @patch("services.hospital_service.DATA_GO_KR_API_KEY", "test-key")
    @patch("services.hospital_service.requests.get")
    def test_hospital_is_closed_after_today_hours(self, mock_get):
        response = Mock()
        response.raise_for_status.return_value = None
        response.content = SAMPLE_XML
        mock_get.return_value = response

        hospitals = get_nearby_hospitals(
            36.893633,
            128.7312033,
            "경상북도",
            "봉화군",
            radius_m=5000,
            now=MONDAY_6_PM,
        )

        self.assertFalse(hospitals[0]["is_open"])
        self.assertEqual(hospitals[0]["open_status"], "closed")

    @patch("services.hospital_service.DATA_GO_KR_API_KEY", "test-key")
    @patch("services.hospital_service.requests.get")
    def test_missing_today_hours_returns_unknown(self, mock_get):
        response = Mock()
        response.raise_for_status.return_value = None
        response.content = SAMPLE_XML
        mock_get.return_value = response

        hospitals = get_nearby_hospitals(
            36.893633,
            128.7312033,
            "경상북도",
            "봉화군",
            radius_m=5000,
            now=SUNDAY_NOON,
        )

        self.assertIsNone(hospitals[0]["is_open"])
        self.assertEqual(hospitals[0]["open_status"], "unknown")
        self.assertIsNone(hospitals[0]["today_hours"])

    @patch("services.hospital_service.DATA_GO_KR_API_KEY", "test-key")
    @patch("services.hospital_service.requests.get")
    def test_search_hospitals_without_location_has_null_distance(self, mock_get):
        response = Mock()
        response.raise_for_status.return_value = None
        response.content = SAMPLE_XML
        mock_get.return_value = response

        hospitals = search_hospitals("병원", limit=1, now=MONDAY_10_AM)

        self.assertEqual(len(hospitals), 1)
        self.assertIsNone(hospitals[0]["distance_m"])
        params = mock_get.call_args.kwargs["params"]
        self.assertEqual(params["QN"], "병원")
        self.assertEqual(params["numOfRows"], 1)

    def test_parse_hospital_response_rejects_invalid_xml(self):
        with self.assertRaises(HospitalServiceError):
            _parse_hospital_response(b"not xml")

    def test_parse_hospital_response_rejects_api_error(self):
        xml = b"""
        <response>
          <header><resultCode>30</resultCode></header>
          <body><items /></body>
        </response>
        """

        with self.assertRaises(HospitalServiceError):
            _parse_hospital_response(xml)


if __name__ == "__main__":
    unittest.main()
