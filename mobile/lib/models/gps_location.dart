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

  bool get hasRegion =>
      sido != null &&
      sido!.isNotEmpty &&
      sigungu != null &&
      sigungu!.isNotEmpty;

  String get displayName {
    final parts = <String>[
      if (sido != null && sido!.isNotEmpty) sido!,
      if (sigungu != null && sigungu!.isNotEmpty) sigungu!,
      if (eupMyeonDong != null && eupMyeonDong!.isNotEmpty) eupMyeonDong!,
      if (referenceName != null && referenceName!.isNotEmpty) referenceName!,
    ];

    return parts.isEmpty ? '현재 위치' : parts.toSet().join(' ');
  }

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
