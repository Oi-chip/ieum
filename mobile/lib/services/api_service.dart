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
  ApiService._();

  static final ApiService instance = ApiService._();

  static String get _baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return Platform.isAndroid
        ? 'http://10.0.2.2:5000'
        : 'http://localhost:5000';
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? parameters,
  ]) async {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: parameters);
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 25));
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

  Future<List<BusStopData>> getNearbyBusStops(GpsLocation location) async {
    final body = await _get(
      '/api/bus/nearby',
      location.toQueryParameters(includeRegion: false),
    );
    final items =
        (body['data'] as Map<String, dynamic>)['stops'] as List? ?? [];
    return items
        .whereType<Map>()
        .map((item) => BusStopData.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<BusData>> getBusArrivals(BusStopData stop) async {
    final body = await _get('/api/bus/arrivals', {
      'city_code': stop.cityCode,
      'stop_id': stop.stopId,
    });
    final items =
        (body['data'] as Map<String, dynamic>)['arrivals'] as List? ?? [];
    return items
        .whereType<Map>()
        .map((item) => BusData.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<BusData>> getStopRoutes(BusStopData stop) async {
    final body = await _get('/api/bus/stop-routes', {
      'city_code': stop.cityCode,
      'stop_id': stop.stopId,
    });
    final items =
        (body['data'] as Map<String, dynamic>)['routes'] as List? ?? [];
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
    final route = (body['data'] as Map<String, dynamic>)['route'] as Map;
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
      '$_baseUrl/api/weather',
    ).replace(queryParameters: {'nx': '$nx', 'ny': '$ny', 'date': dateText});

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
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
}
