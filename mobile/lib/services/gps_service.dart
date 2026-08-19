import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/gps_location.dart';

enum GpsErrorCode {
  locationServiceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  positionUnavailable,
  addressUnavailable,
}

class GpsException implements Exception {
  final GpsErrorCode code;
  final String message;

  const GpsException(this.code, this.message);

  @override
  String toString() => message;
}

/// 현재 GPS 좌표와 한국어 주소를 가져오는 공통 서비스입니다.
class GpsService {
  GpsService._();

  static final GpsService instance = GpsService._();

  final Geocoding _geocoding = Geocoding();
  static const Locale _koreanLocale = Locale('ko', 'KR');

  GpsLocation? _lastLocation;

  /// 가장 최근에 정상적으로 가져온 위치입니다.
  GpsLocation? get lastLocation => _lastLocation;

  /// 현재 위치를 한 번 가져옵니다.
  ///
  /// 병원 API처럼 `sido`, `sigungu`가 꼭 필요한 경우에는
  /// [requireRegion]을 true로 설정합니다.
  Future<GpsLocation> getCurrentLocation({bool requireRegion = false}) async {
    try {
      await _ensureLocationPermission();
    } on GpsException {
      rethrow;
    } catch (_) {
      throw const GpsException(
        GpsErrorCode.positionUnavailable,
        '위치 기능을 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }

    late final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      throw const GpsException(
        GpsErrorCode.timeout,
        '현재 위치를 찾는 데 시간이 오래 걸립니다. GPS 신호를 확인해 주세요.',
      );
    } on LocationServiceDisabledException {
      throw const GpsException(
        GpsErrorCode.locationServiceDisabled,
        '휴대전화의 위치 기능을 켜 주세요.',
      );
    } catch (_) {
      throw const GpsException(
        GpsErrorCode.positionUnavailable,
        '현재 위치를 가져오지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }

    final placemark = await _getPlacemark(
      position.latitude,
      position.longitude,
    );
    final location = _buildLocation(position, placemark);

    if (requireRegion && !location.hasRegion) {
      throw const GpsException(
        GpsErrorCode.addressUnavailable,
        '현재 좌표의 시도와 시군구를 확인하지 못했습니다.',
      );
    }

    _lastLocation = location;
    return location;
  }

  /// 위치 기능이 꺼졌을 때 휴대전화의 위치 설정 화면을 엽니다.
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// 위치 권한을 영구적으로 거절했을 때 앱 설정 화면을 엽니다.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<void> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const GpsException(
        GpsErrorCode.locationServiceDisabled,
        '휴대전화의 위치 기능을 켜 주세요.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const GpsException(
        GpsErrorCode.permissionDenied,
        '현재 위치를 사용하려면 위치 권한이 필요합니다.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const GpsException(
        GpsErrorCode.permissionDeniedForever,
        '앱 설정에서 위치 권한을 허용해 주세요.',
      );
    }
  }

  Future<Placemark?> _getPlacemark(double latitude, double longitude) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
        locale: _koreanLocale,
      );
      return placemarks.isEmpty ? null : placemarks.first;
    } catch (_) {
      // 주소 변환에 실패해도 버스 API에는 GPS 좌표를 사용할 수 있습니다.
      return null;
    }
  }

  GpsLocation _buildLocation(Position position, Placemark? placemark) {
    final sido = _clean(placemark?.administrativeArea);
    final sigungu = _findSigungu(placemark, sido);
    final eupMyeonDong = _findEupMyeonDong(placemark, sigungu);
    final address = _buildAddress(placemark);

    return GpsLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyM: position.accuracy,
      measuredAt: position.timestamp,
      sido: sido,
      sigungu: sigungu,
      eupMyeonDong: eupMyeonDong,
      address: address,
    );
  }

  String? _findSigungu(Placemark? placemark, String? sido) {
    final candidates = [
      _clean(placemark?.subAdministrativeArea),
      _clean(placemark?.locality),
    ];

    for (final candidate in candidates) {
      if (candidate != null &&
          candidate != sido &&
          RegExp(r'[시군구]$').hasMatch(candidate)) {
        return candidate;
      }
    }

    return candidates
        .whereType<String>()
        .where((value) => value != sido)
        .firstOrNull;
  }

  String? _findEupMyeonDong(Placemark? placemark, String? sigungu) {
    final candidates = [
      _clean(placemark?.subLocality),
      _clean(placemark?.locality),
    ];

    return candidates
        .whereType<String>()
        .where((value) => value != sigungu)
        .firstOrNull;
  }

  String? _buildAddress(Placemark? placemark) {
    final street = _clean(placemark?.street);
    if (street != null) {
      return street;
    }

    final parts = [
      _clean(placemark?.administrativeArea),
      _clean(placemark?.subAdministrativeArea),
      _clean(placemark?.locality),
      _clean(placemark?.subLocality),
      _clean(placemark?.thoroughfare),
      _clean(placemark?.subThoroughfare),
    ].whereType<String>().toSet().toList();

    return parts.isEmpty ? null : parts.join(' ');
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
