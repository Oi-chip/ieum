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
}
