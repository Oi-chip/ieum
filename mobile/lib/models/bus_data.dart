// 가까운 버스 정류장 정보
class BusStopData {
  final String stopId;
  final String cityCode;
  final String stopName;
  final String? stopNumber;
  final int distanceM;

  const BusStopData({
    required this.stopId,
    required this.cityCode,
    required this.stopName,
    this.stopNumber,
    required this.distanceM,
  });

  factory BusStopData.fromJson(Map<String, dynamic> json) => BusStopData(
    stopId: json['id'].toString(),
    cityCode: json['city_code'].toString(),
    stopName: json['name'].toString(),
    stopNumber: json['number']?.toString(),
    distanceM: (json['distance_m'] as num?)?.round() ?? 0,
  );
}

// 버스 목록 카드에 표시할 정보
class BusData {
  final String routeId;
  final String? cityCode;
  final String busNumber;
  final String? routeType;

  final String? startStop;
  final String? endStop;
  final String? viaStop;

  // 검색했을 때 실제로 일치한 목적지 정류장
  // 예: 사용자가 "영주" 검색 → "영주여객"이 저장될 수 있음
  final String? matchedStop;

  // 현재 정류장까지 남은 정류장 수
  final int? remainingStops;

  // 도착 예상 시간
  // 실시간 정보가 없으면 null
  final int? arrivalMinutes;

  // 즐겨찾기 여부
  final bool isFavorite;

  const BusData({
    required this.routeId,
    this.cityCode,
    required this.busNumber,
    this.routeType,
    this.startStop,
    this.endStop,
    this.viaStop,
    this.matchedStop,
    this.remainingStops,
    this.arrivalMinutes,
    this.isFavorite = false,
  });

  factory BusData.fromJson(Map<String, dynamic> json) => BusData(
    routeId: json['route_id'].toString(),
    cityCode: json['city_code']?.toString(),
    busNumber: json['bus_number'].toString(),
    routeType: json['route_type']?.toString(),
    startStop: json['start_stop']?.toString(),
    endStop: json['end_stop']?.toString(),
    viaStop: json['via_stop']?.toString(),
    remainingStops: (json['remaining_stops'] as num?)?.round(),
    arrivalMinutes: (json['arrival_minutes'] as num?)?.round(),
  );

  // 즐겨찾기 상태만 변경할 때 사용
  BusData copyWith({bool? isFavorite}) {
    return BusData(
      routeId: routeId,
      cityCode: cityCode,
      busNumber: busNumber,
      routeType: routeType,
      startStop: startStop,
      endStop: endStop,
      viaStop: viaStop,
      matchedStop: matchedStop,
      remainingStops: remainingStops,
      arrivalMinutes: arrivalMinutes,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

// 버스 노선에 포함된 정류장 정보
class BusRouteStopData {
  final String stopId;
  final String stopName;
  final String? stopNumber;
  final int order;

  const BusRouteStopData({
    required this.stopId,
    required this.stopName,
    this.stopNumber,
    required this.order,
  });

  factory BusRouteStopData.fromJson(Map<String, dynamic> json) =>
      BusRouteStopData(
        stopId: json['id'].toString(),
        stopName: json['name'].toString(),
        stopNumber: json['number']?.toString(),
        order: (json['order'] as num).round(),
      );
}

// 버스 상세정보 화면 데이터
class BusDetailData {
  final BusStopData nearbyStop;
  final BusData bus;

  final String? firstBusTime;
  final String? lastBusTime;

  final int? weekdayIntervalMinutes;
  final int? saturdayIntervalMinutes;
  final int? sundayIntervalMinutes;

  final List<BusRouteStopData> stops;

  const BusDetailData({
    required this.nearbyStop,
    required this.bus,
    this.firstBusTime,
    this.lastBusTime,
    this.weekdayIntervalMinutes,
    this.saturdayIntervalMinutes,
    this.sundayIntervalMinutes,
    required this.stops,
  });

  factory BusDetailData.fromJson(
    Map<String, dynamic> json,
    BusStopData nearbyStop,
    BusData currentBus,
  ) => BusDetailData(
    nearbyStop: nearbyStop,
    bus: BusData(
      routeId: json['id'].toString(),
      cityCode: currentBus.cityCode,
      busNumber: json['number'].toString(),
      routeType: json['type']?.toString(),
      startStop: json['start_stop']?.toString(),
      endStop: json['end_stop']?.toString(),
      viaStop: json['via_stop']?.toString(),
      remainingStops: currentBus.remainingStops,
      arrivalMinutes: currentBus.arrivalMinutes,
      isFavorite: currentBus.isFavorite,
    ),
    firstBusTime: json['first_bus_time']?.toString(),
    lastBusTime: json['last_bus_time']?.toString(),
    weekdayIntervalMinutes: (json['weekday_interval_minutes'] as num?)?.round(),
    saturdayIntervalMinutes: (json['saturday_interval_minutes'] as num?)
        ?.round(),
    sundayIntervalMinutes: (json['sunday_interval_minutes'] as num?)?.round(),
    stops: (json['stops'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) => BusRouteStopData.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
  );
}
