import 'dart:math' as math;

import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gps_location.dart';
import 'gps_service.dart';

class WeatherGrid {
  final int nx;
  final int ny;

  const WeatherGrid(this.nx, this.ny);
}

class SelectedLocationService {
  SelectedLocationService._();

  static final SelectedLocationService instance = SelectedLocationService._();
  static const String selectedRegionKey = 'selectedRegion';
  static const Map<String, List<double>> _fixedRegionCoordinates = {
    // 봉화군은 군청 앞 정류장 좌표를 기준으로 조회한다.
    '경상북도 봉화군': [36.89101, 128.7331261],
  };

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final Geocoding _geocoding = Geocoding();

  Future<bool> usesCurrentLocation() async {
    final selected =
        await _preferences.getString(selectedRegionKey) ?? '현재 위치';
    return selected == '현재 위치';
  }

  Future<GpsLocation> getLocation({bool requireRegion = false}) async {
    final selected =
        await _preferences.getString(selectedRegionKey) ?? '현재 위치';
    if (selected == '현재 위치') {
      return GpsService.instance.getCurrentLocation(
        requireRegion: requireRegion,
      );
    }

    final parts = selected.split(' ');
    final sido = parts.first;
    final sigungu = parts.skip(1).join(' ');
    final officeQuery = sigungu == '전 지역'
        ? '$sido청'
        : '$sido $sigungu청';
    final fixedCoordinates = _fixedRegionCoordinates[selected];
    if (fixedCoordinates != null) {
      return GpsLocation(
        latitude: fixedCoordinates[0],
        longitude: fixedCoordinates[1],
        accuracyM: 0,
        measuredAt: DateTime.now(),
        sido: sido,
        sigungu: sigungu,
        address: officeQuery,
        referenceName: sigungu == '전 지역' ? '$sido청' : '$sigungu청',
      );
    }
    try {
      final locations = await _geocoding.locationFromAddress(officeQuery);
      if (locations.isEmpty) {
        throw const GpsException(
          GpsErrorCode.positionUnavailable,
          '선택한 지역의 시청·군청·구청 위치를 찾지 못했습니다.',
        );
      }
      final location = locations.first;
      return GpsLocation(
        latitude: location.latitude,
        longitude: location.longitude,
        accuracyM: 0,
        measuredAt: DateTime.now(),
        sido: sido,
        sigungu: sigungu == '전 지역' ? sido : sigungu,
        address: officeQuery,
        referenceName: sigungu == '전 지역' ? '$sido청' : '$sigungu청',
      );
    } on GpsException {
      rethrow;
    } catch (_) {
      throw const GpsException(
        GpsErrorCode.positionUnavailable,
        '선택한 지역의 시청·군청·구청 좌표를 확인하지 못했습니다. 네트워크를 확인해 주세요.',
      );
    }
  }

  WeatherGrid weatherGrid(GpsLocation location) {
    const re = 6371.00877 / 5.0;
    const slat1 = 30.0;
    const slat2 = 60.0;
    const olon = 126.0;
    const olat = 38.0;
    const xo = 43.0;
    const yo = 136.0;
    const degrad = math.pi / 180.0;

    var sn = math.tan(math.pi * 0.25 + slat2 * degrad * 0.5) /
        math.tan(math.pi * 0.25 + slat1 * degrad * 0.5);
    sn = math.log(math.cos(slat1 * degrad) / math.cos(slat2 * degrad)) /
        math.log(sn);
    var sf = math.tan(math.pi * 0.25 + slat1 * degrad * 0.5);
    sf = math.pow(sf, sn).toDouble() * math.cos(slat1 * degrad) / sn;
    var ro = math.tan(math.pi * 0.25 + olat * degrad * 0.5);
    ro = re * sf / math.pow(ro, sn);
    var ra = math.tan(
      math.pi * 0.25 + location.latitude * degrad * 0.5,
    );
    ra = re * sf / math.pow(ra, sn);
    var theta = location.longitude * degrad - olon * degrad;
    if (theta > math.pi) theta -= 2.0 * math.pi;
    if (theta < -math.pi) theta += 2.0 * math.pi;
    theta *= sn;
    return WeatherGrid(
      (ra * math.sin(theta) + xo + 0.5).floor(),
      (ro - ra * math.cos(theta) + yo + 0.5).floor(),
    );
  }
}
