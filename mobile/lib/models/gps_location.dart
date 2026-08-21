/// GPS 좌표와 좌표를 주소로 변환한 결과를 함께 보관합니다.
class GpsLocation {
  final double latitude;
  final double longitude;
  final double accuracyM;
  final DateTime measuredAt;
  final String? sido;
  final String? sigungu;
  final String? eupMyeonDong;
  final String? address;
  final String? referenceName;

  const GpsLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.measuredAt,
    this.sido,
    this.sigungu,
    this.eupMyeonDong,
    this.address,
    this.referenceName,
  });

  /// 병원 지역 검색에 필요한 시도와 시군구가 모두 있는지 확인합니다.
  bool get hasRegion =>
      sido != null &&
      sido!.isNotEmpty &&
      sigungu != null &&
      sigungu!.isNotEmpty;

  /// 화면에 보여줄 짧은 현재 위치 이름입니다.
  String get displayName {
    final parts = <String>[
      if (sido != null && sido!.isNotEmpty) sido!,
      if (sigungu != null && sigungu!.isNotEmpty) sigungu!,
      if (eupMyeonDong != null && eupMyeonDong!.isNotEmpty) eupMyeonDong!,
      if (referenceName != null && referenceName!.isNotEmpty) referenceName!,
    ];

    return parts.isEmpty ? '현재 위치' : parts.toSet().join(' ');
  }

  /// 버스와 병원 API의 쿼리 파라미터로 바로 사용할 수 있습니다.
  Map<String, String> toQueryParameters({bool includeRegion = true}) {
    return {
      'latitude': latitude.toStringAsFixed(7),
      'longitude': longitude.toStringAsFixed(7),
      if (includeRegion && sido != null && sido!.isNotEmpty) 'sido': sido!,
      if (includeRegion && sigungu != null && sigungu!.isNotEmpty)
        'sigungu': sigungu!,
    };
  }
}
