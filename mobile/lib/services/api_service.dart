import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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
    return Platform.isAndroid ? 'http://10.0.2.2:5000' : 'http://localhost:5000';
  }

  Future<Map<String, dynamic>> getWeather(DateTime date) async {
    final dateText = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse('$_baseUrl/api/weather').replace(queryParameters: {
      'nx': '90',
      'ny': '106',
      'date': dateText,
    });

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
}
