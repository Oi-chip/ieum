import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/gps_location.dart';

void main() {
  final location = GpsLocation(
    latitude: 36.893633,
    longitude: 128.7312033,
    accuracyM: 8.5,
    measuredAt: DateTime.utc(2026, 8, 19),
    sido: '경상북도',
    sigungu: '봉화군',
    eupMyeonDong: '봉화읍',
    address: '경상북도 봉화군 봉화읍',
  );

  test('화면 표시용 위치 이름을 만든다', () {
    expect(location.displayName, '경상북도 봉화군 봉화읍');
    expect(location.hasRegion, isTrue);
  });

  test('병원 API용 위치 파라미터를 만든다', () {
    expect(location.toQueryParameters(), {
      'latitude': '36.8936330',
      'longitude': '128.7312033',
      'sido': '경상북도',
      'sigungu': '봉화군',
    });
  });

  test('버스 API용 파라미터에서는 지역을 제외할 수 있다', () {
    expect(location.toQueryParameters(includeRegion: false), {
      'latitude': '36.8936330',
      'longitude': '128.7312033',
    });
  });
}
