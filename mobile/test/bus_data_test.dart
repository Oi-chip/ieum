import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/bus_data.dart';
import 'package:mobile/models/gps_location.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/favorite_bus_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const routeId = 'TSB356000197';

  Map<String, dynamic> searchRouteJson() => {
    'route_id': routeId,
    'city_code': '37060',
    'bus_number': '33',
    'api_bus_number': '29',
    'route_type': '일반버스',
    'start_stop': '삼양홈마트',
    'end_stop': '영주여객차고지',
    'via_stop': '봉화공용터미널',
    'boarding_stop': {
      'id': 'BOARD',
      'city_code': '37060',
      'name': '봉화공용터미널',
      'number': '12345',
      'distance_m': 82,
      'latitude': 36.89101,
      'longitude': 128.7331261,
    },
    'destination_stop': {
      'id': 'DEST',
      'name': '영주여객',
      'number': '67890',
      'order': 18,
      'latitude': 36.805,
      'longitude': 128.624,
      'direction_code': '1',
    },
    'matched_stop': '영주여객',
    'boarding_order': 4,
    'destination_order': 18,
    'stops_between': 14,
    'remaining_stops': 2,
    'arrival_minutes': 7,
    'vehicle_type': '저상버스',
    'first_bus_time': '06:10',
    'last_bus_time': '21:40',
    'weekday_interval_minutes': 30,
    'saturday_interval_minutes': 40,
    'sunday_interval_minutes': 50,
    'data_complete': false,
    'unavailable_fields': ['route_info'],
  };

  test('정류장 좌표와 노선 정류장 방향 정보를 파싱한다', () {
    final stop = BusStopData.fromJson({
      'id': 'STOP',
      'city_code': '37410',
      'name': '봉화공용터미널',
      'number': '10001',
      'distance_m': 42,
      'latitude': '36.89101',
      'longitude': 128.7331261,
    });
    final routeStop = BusRouteStopData.fromJson({
      'id': 'ROUTE_STOP',
      'name': '영주여객',
      'number': '20002',
      'order': '18',
      'latitude': 36.805,
      'longitude': '128.624',
      'direction_code': 1,
    });

    expect(stop.latitude, 36.89101);
    expect(stop.longitude, 128.7331261);
    expect(routeStop.order, 18);
    expect(routeStop.latitude, 36.805);
    expect(routeStop.longitude, 128.624);
    expect(routeStop.directionCode, '1');
  });

  test('검색 노선의 모든 확장 필드와 복합 노선 키를 파싱한다', () {
    final bus = BusData.fromJson(searchRouteJson());

    expect(bus.routeKey, '37060:$routeId');
    expect(bus.busNumber, '33');
    expect(bus.apiBusNumber, '29');
    expect(bus.boardingStop?.stopId, 'BOARD');
    expect(bus.boardingStop?.distanceM, 82);
    expect(bus.destinationStop?.stopId, 'DEST');
    expect(bus.destinationStop?.cityCode, '37060');
    expect(bus.matchedStop, '영주여객');
    expect(bus.boardingOrder, 4);
    expect(bus.destinationOrder, 18);
    expect(bus.stopsBetween, 14);
    expect(bus.vehicleType, '저상버스');
    expect(bus.firstBusTime, '06:10');
    expect(bus.lastBusTime, '21:40');
    expect(bus.weekdayIntervalMinutes, 30);
    expect(bus.saturdayIntervalMinutes, 40);
    expect(bus.sundayIntervalMinutes, 50);
    expect(bus.dataComplete, isFalse);
    expect(bus.unavailableFields, ['route_info']);
  });

  test('copyWith는 즐겨찾기 변경 시 API 검색 정보를 모두 보존한다', () {
    final bus = BusData.fromJson(searchRouteJson());
    final copied = bus.copyWith(isFavorite: true);

    expect(copied.isFavorite, isTrue);
    expect(copied.routeKey, bus.routeKey);
    expect(copied.apiBusNumber, bus.apiBusNumber);
    expect(copied.boardingStop, same(bus.boardingStop));
    expect(copied.destinationStop, same(bus.destinationStop));
    expect(copied.matchedStop, bus.matchedStop);
    expect(copied.boardingOrder, bus.boardingOrder);
    expect(copied.destinationOrder, bus.destinationOrder);
    expect(copied.stopsBetween, bus.stopsBetween);
    expect(copied.vehicleType, bus.vehicleType);
    expect(copied.firstBusTime, bus.firstBusTime);
    expect(copied.lastBusTime, bus.lastBusTime);
    expect(copied.weekdayIntervalMinutes, bus.weekdayIntervalMinutes);
    expect(copied.saturdayIntervalMinutes, bus.saturdayIntervalMinutes);
    expect(copied.sundayIntervalMinutes, bus.sundayIntervalMinutes);
    expect(copied.dataComplete, bus.dataComplete);
    expect(copied.unavailableFields, bus.unavailableFields);
  });

  test('원본 API 노선번호가 없으면 표시 노선번호를 사용한다', () {
    const constructed = BusData(routeId: 'R1', busNumber: '12');
    final parsed = BusData.fromJson({'route_id': 'R2', 'bus_number': '34'});

    expect(constructed.apiBusNumber, '12');
    expect(parsed.apiBusNumber, '34');
    expect(parsed.routeKey, 'R2');
  });

  test('overview와 search 응답 메타데이터를 파싱한다', () {
    final overview = BusOverviewData.fromJson({
      'stops': [
        {
          'id': 'BOARD',
          'city_code': '37060',
          'name': '봉화공용터미널',
          'distance_m': 82,
        },
      ],
      'routes': [searchRouteJson()],
      'arrival_information_unavailable': true,
      'partial': true,
      'unavailable_stop_count': 2,
      'unavailable_provider_count': 1,
      'unavailable_arrival_provider_count': 3,
    });
    final search = BusSearchData.fromJson({
      'destination': '영주',
      'routes': [searchRouteJson()],
      'searched_route_count': 17,
      'origin_stop_count': 8,
      'unavailable_route_count': 3,
      'unavailable_stop_count': 1,
      'unavailable_provider_count': 2,
      'incomplete_result_count': 4,
      'unavailable_arrival_stop_count': 2,
      'arrival_information_unavailable': true,
      'provider_discovery_unavailable': false,
      'destination_provider_city_codes': ['37060'],
    });

    expect(overview.stops.single.stopId, 'BOARD');
    expect(overview.routes.single.routeKey, '37060:$routeId');
    expect(overview.arrivalInformationUnavailable, isTrue);
    expect(overview.partial, isTrue);
    expect(overview.unavailableStopCount, 2);
    expect(overview.unavailableProviderCount, 1);
    expect(overview.unavailableArrivalProviderCount, 3);
    expect(search.destination, '영주');
    expect(search.routes.single.matchedStop, '영주여객');
    expect(search.searchedRouteCount, 17);
    expect(search.originStopCount, 8);
    expect(search.unavailableRouteCount, 3);
    expect(search.unavailableStopCount, 1);
    expect(search.unavailableProviderCount, 2);
    expect(search.incompleteResultCount, 4);
    expect(search.unavailableArrivalStopCount, 2);
    expect(search.arrivalInformationUnavailable, isTrue);
    expect(search.providerDiscoveryUnavailable, isFalse);
    expect(search.destinationProviderCityCodes, ['37060']);
    expect(search.partial, isTrue);
  });

  test('상세 응답 누락 필드는 검색 결과 값으로 보존한다', () {
    final currentBus = BusData.fromJson(
      searchRouteJson(),
    ).copyWith(isFavorite: true);
    const nearbyStop = BusStopData(
      stopId: 'BOARD',
      cityCode: '37060',
      stopName: '봉화공용터미널',
      distanceM: 82,
    );
    final detail = BusDetailData.fromJson(
      {
        'id': routeId,
        'number': '33',
        'api_number': '29',
        'first_bus_time': '06:00',
        'stops': [
          {
            'id': 'BOARD',
            'name': '봉화공용터미널',
            'number': '12345',
            'order': 4,
            'latitude': 36.89101,
            'longitude': 128.7331261,
            'direction_code': '0',
          },
        ],
      },
      nearbyStop,
      currentBus,
    );

    expect(detail.bus.apiBusNumber, '29');
    expect(detail.bus.boardingStop, same(currentBus.boardingStop));
    expect(detail.bus.destinationStop, same(currentBus.destinationStop));
    expect(detail.bus.matchedStop, currentBus.matchedStop);
    expect(detail.bus.stopsBetween, 14);
    expect(detail.bus.vehicleType, '저상버스');
    expect(detail.bus.firstBusTime, '06:00');
    expect(detail.bus.lastBusTime, '21:40');
    expect(detail.bus.dataComplete, isFalse);
    expect(detail.bus.unavailableFields, ['route_info']);
    expect(detail.bus.isFavorite, isTrue);
    expect(detail.firstBusTime, '06:00');
    expect(detail.lastBusTime, '21:40');
    expect(detail.stops.single.directionCode, '0');
    expect(detail.stops.single.latitude, 36.89101);
  });

  test('동시에 추가한 복합 노선 즐겨찾기를 모두 보존한다', () async {
    SharedPreferences.setMockInitialValues({});

    await Future.wait([
      FavoriteBusService.toggleFavorite('37410:ROUTE-1'),
      FavoriteBusService.toggleFavorite('37060:ROUTE-2'),
    ]);

    expect(await FavoriteBusService.getFavoriteRouteIds(), {
      '37410:ROUTE-1',
      '37060:ROUTE-2',
    });
  });

  test('기존 routeId 즐겨찾기를 복합 키 토글로 마이그레이션한다', () async {
    SharedPreferences.setMockInitialValues({
      'favorite_bus_route_ids': ['ROUTE-1'],
    });

    final removed = await FavoriteBusService.toggleFavorite(
      '37410:ROUTE-1',
      legacyRouteId: 'ROUTE-1',
    );
    final added = await FavoriteBusService.toggleFavorite(
      '37410:ROUTE-1',
      legacyRouteId: 'ROUTE-1',
    );

    expect(removed, isFalse);
    expect(added, isTrue);
    expect(await FavoriteBusService.getFavoriteRouteIds(), {'37410:ROUTE-1'});
  });

  test('검색 API에 선택한 출발·도착 정류장 키를 함께 보낸다', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        '{"success":true,"data":{"destination":"영주","routes":[]}}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = ApiService.withClient(client, baseUrl: 'http://example.test');
    final location = GpsLocation(
      latitude: 36.89101,
      longitude: 128.7331261,
      accuracyM: 0,
      measuredAt: DateTime(2026, 8, 22),
    );
    const origin = BusStopData(
      stopId: 'TSB371000047',
      cityCode: '37410',
      stopName: '삼양홈마트',
      distanceM: 207,
    );
    const destination = BusStopData(
      stopId: 'TSB356000631',
      cityCode: '37060',
      stopName: '영주고추시장',
      distanceM: 0,
    );

    await api.searchBusRoutes(
      location,
      ' 영주 ',
      originStop: origin,
      destinationStop: destination,
    );

    expect(requestedUri.path, '/api/bus/search');
    expect(requestedUri.queryParameters['latitude'], '36.8910100');
    expect(requestedUri.queryParameters['longitude'], '128.7331261');
    expect(requestedUri.queryParameters['destination'], '영주');
    expect(requestedUri.queryParameters['origin_stop_id'], origin.stopId);
    expect(requestedUri.queryParameters['origin_city_code'], origin.cityCode);
    expect(
      requestedUri.queryParameters['destination_stop_id'],
      destination.stopId,
    );
    expect(
      requestedUri.queryParameters['destination_city_code'],
      destination.cityCode,
    );
  });

  test('도착지역 기준 정류장 목록을 요청한다', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'destination': '영주',
            'stops': [
              {
                'id': 'TSB356000008',
                'city_code': '37060',
                'name': '영주역',
                'number': '3560008',
                'latitude': 36.810486,
                'longitude': 128.624387,
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = ApiService.withClient(client, baseUrl: 'http://example.test');
    final location = GpsLocation(
      latitude: 36.89101,
      longitude: 128.7331261,
      accuracyM: 0,
      measuredAt: DateTime(2026, 8, 27),
    );

    final stops = await api.searchBusDestinationStops(location, ' 영주 ');

    expect(requestedUri.path, '/api/bus/destination-stops');
    expect(requestedUri.queryParameters['destination'], '영주');
    expect(stops.single.stopName, '영주역');
    expect(stops.single.cityCode, '37060');
  });

  test('overview와 search만 집계형 버스 timeout을 사용한다', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final data = switch (request.url.path) {
        '/api/bus/overview' => {
          'stops': <Map<String, dynamic>>[],
          'routes': <Map<String, dynamic>>[],
        },
        '/api/bus/search' || '/api/bus/destination-stops' => {
          'destination': '영주',
          'routes': <Map<String, dynamic>>[],
          'stops': <Map<String, dynamic>>[],
        },
        _ => {'stops': <Map<String, dynamic>>[]},
      };
      return http.Response(
        jsonEncode({'success': true, 'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = ApiService.withClient(
      client,
      baseUrl: 'http://example.test',
      defaultRequestTimeout: const Duration(milliseconds: 5),
      busAggregateRequestTimeout: const Duration(seconds: 1),
    );
    final location = GpsLocation(
      latitude: 36.89101,
      longitude: 128.7331261,
      accuracyM: 0,
      measuredAt: DateTime(2026, 8, 22),
    );

    await expectLater(
      api.getNearbyBusStops(location),
      throwsA(isA<ApiException>()),
    );
    await expectLater(api.getBusOverview(location), completes);
    await expectLater(api.searchBusDestinationStops(location, '영주'), completes);
    await expectLater(api.searchBusRoutes(location, '영주'), completes);
  });
}
