import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/bus_data.dart';
import '../models/gps_location.dart';
import '../models/hospital_data.dart';

class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  static const Duration _defaultRequestTimeout = Duration(seconds: 25);
  static const Duration _busAggregateRequestTimeout = Duration(seconds: 45);

  ApiService._({
    http.Client? client,
    String? baseUrl,
    Duration defaultRequestTimeout = _defaultRequestTimeout,
    Duration busAggregateRequestTimeout = _busAggregateRequestTimeout,
  }) : _client = client ?? http.Client(),
       _baseUrlOverride = baseUrl,
       _defaultTimeout = defaultRequestTimeout,
       _busAggregateTimeout = busAggregateRequestTimeout;

  static final ApiService instance = ApiService._();
  final http.Client _client;
  final String? _baseUrlOverride;
  final Duration _defaultTimeout;
  final Duration _busAggregateTimeout;

  factory ApiService.withClient(
    http.Client client, {
    required String baseUrl,
    Duration defaultRequestTimeout = _defaultRequestTimeout,
    Duration busAggregateRequestTimeout = _busAggregateRequestTimeout,
  }) {
    return ApiService._(
      client: client,
      baseUrl: baseUrl,
      defaultRequestTimeout: defaultRequestTimeout,
      busAggregateRequestTimeout: busAggregateRequestTimeout,
    );
  }

  static String get _baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return Platform.isAndroid
        ? 'http://10.0.2.2:5000'
        : 'http://localhost:5000';
  }

  String get _resolvedBaseUrl => _baseUrlOverride ?? _baseUrl;

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? parameters,
    Duration? timeout,
  ]) async {
    final uri = Uri.parse(
      '$_resolvedBaseUrl$path',
    ).replace(queryParameters: parameters);
    try {
      final response = await _client
          .get(uri)
          .timeout(timeout ?? _defaultTimeout);
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) {
        throw const ApiException('서버가 올바르게 응답하지 않았습니다.');
      }
      if (response.statusCode != 200 || body['success'] != true) {
        final error = body['error'];
        throw ApiException(
          error is Map
              ? error['message']?.toString() ?? '정보를 불러오지 못했습니다.'
              : '정보를 불러오지 못했습니다.',
        );
      }
      return body;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('서버에 연결할 수 없습니다.');
    }
  }

  Map<String, dynamic> _responseData(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is! Map) {
      throw const ApiException('서버가 올바르게 응답하지 않았습니다.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<List<BusStopData>> getNearbyBusStops(GpsLocation location) async {
    final body = await _get(
      '/api/bus/nearby',
      location.toQueryParameters(includeRegion: false),
    );
    final items = _responseData(body)['stops'] as List? ?? [];
    return items
        .whereType<Map>()
        .map((item) => BusStopData.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<BusOverviewData> getBusOverview(GpsLocation location) async {
    final body = await _get(
      '/api/bus/overview',
      location.toQueryParameters(includeRegion: false),
      _busAggregateTimeout,
    );
    return BusOverviewData.fromJson(_responseData(body));
  }

  Future<BusSearchData> searchBusRoutes(
    GpsLocation location,
    String destination, {
    BusStopData? originStop,
  }) async {
    final parameters = location.toQueryParameters(includeRegion: false)
      ..['destination'] = destination.trim();
    if (originStop != null) {
      parameters.addAll({
        'origin_stop_id': originStop.stopId,
        'origin_city_code': originStop.cityCode,
      });
    }

    final body = await _get(
      '/api/bus/search',
      parameters,
      _busAggregateTimeout,
    );
    return BusSearchData.fromJson(_responseData(body));
  }

  Future<List<BusData>> getBusArrivals(BusStopData stop) async {
    final body = await _get('/api/bus/arrivals', {
      'city_code': stop.cityCode,
      'stop_id': stop.stopId,
    });
    final data = _responseData(body);
    final items = data['arrivals'] as List? ?? [];
    return items.whereType<Map>().map((item) {
      final json = Map<String, dynamic>.from(item);
      json.putIfAbsent('city_code', () => data['city_code'] ?? stop.cityCode);
      return BusData.fromJson(json);
    }).toList();
  }

  Future<List<BusData>> getStopRoutes(BusStopData stop) async {
    final body = await _get('/api/bus/stop-routes', {
      'city_code': stop.cityCode,
      'stop_id': stop.stopId,
    });
    final items = _responseData(body)['routes'] as List? ?? [];
    return items
        .whereType<Map>()
        .map((item) => BusData.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<BusDetailData> getBusRoute(BusStopData stop, BusData bus) async {
    final body = await _get('/api/bus/route', {
      'city_code': bus.cityCode ?? stop.cityCode,
      'route_id': bus.routeId,
    });
    final route = _responseData(body)['route'] as Map;
    return BusDetailData.fromJson(Map<String, dynamic>.from(route), stop, bus);
  }

  Future<List<HospitalData>> getNearbyHospitals(
    GpsLocation location, {
    String? keyword,
  }) async {
    final parameters = location.toQueryParameters()
      ..addAll({
        'limit': '20',
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      });
    final body = await _get('/api/hospitals/nearby', parameters);
    final items =
        (body['data'] as Map<String, dynamic>)['hospitals'] as List? ?? [];
    return items
        .whereType<Map>()
        .map((item) => HospitalData.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>> getWeather(
    DateTime date, {
    int nx = 90,
    int ny = 113,
  }) async {
    final dateText =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse(
      '$_resolvedBaseUrl/api/weather',
    ).replace(queryParameters: {'nx': '$nx', 'ny': '$ny', 'date': dateText});

    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 || body is! Map<String, dynamic>) {
        throw const ApiException('날씨 서버가 올바르게 응답하지 않았습니다.');
      }
      if (body['success'] != true || body['data'] is! Map<String, dynamic>) {
        final error = body['error'];
        final message = error is Map ? error['message']?.toString() : null;
        throw ApiException(message ?? '날씨 정보를 불러오지 못했습니다.');
      }
      return body['data'] as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('날씨 서버에 연결할 수 없습니다.');
    }
  }

  // 가까운 버스 정류장 조회
  Future<Map<String, dynamic>> getNearbyBusStops({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/bus/nearby',
    ).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
    );

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (response.statusCode != 200 ||
          body is! Map<String, dynamic>) {
        throw const ApiException(
          '버스 서버가 올바르게 응답하지 않았습니다.',
        );
      }

      if (body['success'] != true ||
          body['data'] is! Map<String, dynamic>) {
        final error = body['error'];
        final message =
            error is Map ? error['message']?.toString() : null;

        throw ApiException(
          message ?? '가까운 정류장을 불러오지 못했습니다.',
        );
      }

      return body['data'] as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        '버스 서버에 연결할 수 없습니다.',
      );
    }
  }

  // 정류장별 버스 도착정보 조회
  Future<Map<String, dynamic>> getBusArrivals({
    required String cityCode,
    required String stopId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/bus/arrivals',
    ).replace(
      queryParameters: {
        'city_code': cityCode,
        'stop_id': stopId,
      },
    );

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (response.statusCode != 200 ||
          body is! Map<String, dynamic>) {
        throw const ApiException(
          '버스 서버가 올바르게 응답하지 않았습니다.',
        );
      }

      if (body['success'] != true ||
          body['data'] is! Map<String, dynamic>) {
        final error = body['error'];
        final message =
            error is Map ? error['message']?.toString() : null;

        throw ApiException(
          message ?? '버스 도착정보를 불러오지 못했습니다.',
        );
      }

      return body['data'] as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        '버스 서버에 연결할 수 없습니다.',
      );
    }
  }

  // 목적지를 지나는 버스 검색
  Future<Map<String, dynamic>> searchBuses({
    required double latitude,
    required double longitude,
    required String destination,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/bus/search',
    ).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'destination': destination,
      },
    );

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (response.statusCode != 200 ||
          body is! Map<String, dynamic>) {
        throw const ApiException(
          '버스 서버가 올바르게 응답하지 않았습니다.',
        );
      }

      if (body['success'] != true ||
          body['data'] is! Map<String, dynamic>) {
        final error = body['error'];
        final message =
            error is Map ? error['message']?.toString() : null;

        throw ApiException(
          message ?? '버스 검색 결과를 불러오지 못했습니다.',
        );
      }

      return body['data'] as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        '버스 처리 중 오류: $error',
      );
    }
  }

  // 버스 노선 상세정보 조회
  Future<Map<String, dynamic>> getBusRoute({
    required String cityCode,
    required String routeId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/bus/route',
    ).replace(
      queryParameters: {
        'city_code': cityCode,
        'route_id': routeId,
      },
    );

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw ApiException(
          '버스 노선정보 서버 오류가 발생했습니다. '
          '(${response.statusCode})',
        );
      }

      final body = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (body is! Map<String, dynamic>) {
        throw const ApiException(
          '버스 노선정보 서버가 올바르게 응답하지 않았습니다.',
        );
      }

      if (body['success'] != true ||
          body['data'] is! Map<String, dynamic>) {
        final error = body['error'];

        final message =
            error is Map ? error['message']?.toString() : null;

        throw ApiException(
          message ?? '버스 노선정보를 불러오지 못했습니다.',
        );
      }

      return body['data'] as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        '버스 서버에 연결할 수 없습니다.',
      );
    }
  }
}
