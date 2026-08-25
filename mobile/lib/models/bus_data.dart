String? _stringValue(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty || text == 'null' ? null : text;
}

int? _intValue(dynamic value) {
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

double? _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

bool _boolValue(dynamic value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  switch (value?.toString().toLowerCase()) {
    case 'true':
    case '1':
      return true;
    case 'false':
    case '0':
      return false;
    default:
      return fallback;
  }
}

Map<String, dynamic>? _mapValue(dynamic value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.map(_stringValue).whereType<String>().toList(growable: false);
}

// 가까운 버스 정류장 정보
class BusStopData {
  final String stopId;
  final String cityCode;
  final String stopName;
  final String? stopNumber;
  final int distanceM;
  final double? latitude;
  final double? longitude;

  const BusStopData({
    required this.stopId,
    required this.cityCode,
    required this.stopName,
    this.stopNumber,
    required this.distanceM,
    this.latitude,
    this.longitude,
  });

  factory BusStopData.fromJson(
    Map<String, dynamic> json, {
    String? fallbackCityCode,
    int fallbackDistanceM = 0,
  }) => BusStopData(
    stopId: _stringValue(json['id'] ?? json['stop_id']) ?? '',
    cityCode: _stringValue(json['city_code']) ?? fallbackCityCode?.trim() ?? '',
    stopName: _stringValue(json['name'] ?? json['stop_name']) ?? '',
    stopNumber: _stringValue(json['number'] ?? json['stop_number']),
    distanceM: _intValue(json['distance_m']) ?? fallbackDistanceM,
    latitude: _doubleValue(json['latitude']),
    longitude: _doubleValue(json['longitude']),
  );
}

BusStopData? _nestedStop(dynamic value, {String? fallbackCityCode}) {
  final json = _mapValue(value);
  if (json == null) return null;
  return BusStopData.fromJson(json, fallbackCityCode: fallbackCityCode);
}

// 버스 목록 카드와 검색 결과에 표시할 정보
class BusData {
  final String routeId;
  final String? cityCode;
  final String busNumber;
  final String apiBusNumber;
  final String? routeType;

  final String? startStop;
  final String? endStop;
  final String? viaStop;

  final BusStopData? boardingStop;
  final BusStopData? destinationStop;

  // 검색했을 때 실제로 일치한 목적지 정류장 이름
  final String? matchedStop;
  final int? boardingOrder;
  final int? destinationOrder;
  final int? stopsBetween;

  // 현재 정류장까지 남은 정류장 수와 도착 예상 시간
  final int? remainingStops;
  final int? arrivalMinutes;
  final String? vehicleType;

  final String? firstBusTime;
  final String? lastBusTime;
  final int? weekdayIntervalMinutes;
  final int? saturdayIntervalMinutes;
  final int? sundayIntervalMinutes;

  // 일부 외부 API를 사용할 수 없을 때 결과의 완전성을 표시합니다.
  final bool dataComplete;
  final List<String> unavailableFields;

  // 즐겨찾기 여부
  final bool isFavorite;

  const BusData({
    required this.routeId,
    this.cityCode,
    required this.busNumber,
    String? apiBusNumber,
    this.routeType,
    this.startStop,
    this.endStop,
    this.viaStop,
    this.boardingStop,
    this.destinationStop,
    this.matchedStop,
    this.boardingOrder,
    this.destinationOrder,
    this.stopsBetween,
    this.remainingStops,
    this.arrivalMinutes,
    this.vehicleType,
    this.firstBusTime,
    this.lastBusTime,
    this.weekdayIntervalMinutes,
    this.saturdayIntervalMinutes,
    this.sundayIntervalMinutes,
    this.dataComplete = true,
    this.unavailableFields = const [],
    this.isFavorite = false,
  }) : apiBusNumber = apiBusNumber ?? busNumber;

  /// TAGO 노선 ID는 제공 도시 코드와 함께 사용할 때 고유합니다.
  String get routeKey {
    final normalizedCityCode = cityCode?.trim();
    return normalizedCityCode == null || normalizedCityCode.isEmpty
        ? routeId
        : '$normalizedCityCode:$routeId';
  }

  factory BusData.fromJson(Map<String, dynamic> json) {
    final cityCode = _stringValue(json['city_code']);
    final busNumber = _stringValue(json['bus_number'] ?? json['number']) ?? '';
    final boardingJson = _mapValue(json['boarding_stop']);
    final matchedStopValue = json['matched_stop'];
    final matchedStopJson = _mapValue(matchedStopValue);
    final destinationStopValue = json['destination_stop'];
    final destinationJson = _mapValue(destinationStopValue) ?? matchedStopJson;
    final boardingStop = _nestedStop(boardingJson, fallbackCityCode: cityCode);
    final destinationStop = _nestedStop(
      destinationJson,
      fallbackCityCode: cityCode,
    );
    final unavailableFields = _stringList(json['unavailable_fields']);

    return BusData(
      routeId: _stringValue(json['route_id'] ?? json['id']) ?? '',
      cityCode: cityCode,
      busNumber: busNumber,
      apiBusNumber:
          _stringValue(json['api_bus_number'] ?? json['api_number']) ??
          busNumber,
      routeType: _stringValue(json['route_type'] ?? json['type']),
      startStop: _stringValue(json['start_stop']),
      endStop: _stringValue(json['end_stop']),
      viaStop: _stringValue(json['via_stop']),
      boardingStop: boardingStop,
      destinationStop: destinationStop,
      matchedStop: matchedStopJson == null
          ? _stringValue(matchedStopValue) ??
                (destinationStopValue is Map
                    ? null
                    : _stringValue(destinationStopValue)) ??
                destinationStop?.stopName
          : destinationStop?.stopName,
      boardingOrder:
          _intValue(json['boarding_order']) ??
          _intValue(boardingJson?['order']),
      destinationOrder:
          _intValue(json['destination_order']) ??
          _intValue(destinationJson?['order']),
      stopsBetween: _intValue(json['stops_between']),
      remainingStops: _intValue(json['remaining_stops']),
      arrivalMinutes: _intValue(json['arrival_minutes']),
      vehicleType: _stringValue(json['vehicle_type']),
      firstBusTime: _stringValue(json['first_bus_time']),
      lastBusTime: _stringValue(json['last_bus_time']),
      weekdayIntervalMinutes: _intValue(json['weekday_interval_minutes']),
      saturdayIntervalMinutes: _intValue(json['saturday_interval_minutes']),
      sundayIntervalMinutes: _intValue(json['sunday_interval_minutes']),
      dataComplete: _boolValue(
        json['data_complete'],
        fallback: unavailableFields.isEmpty,
      ),
      unavailableFields: unavailableFields,
    );
  }

  // 새 객체를 만들 때 API에서 받은 필드가 소실되지 않게 모두 전달합니다.
  BusData copyWith({
    String? routeId,
    String? cityCode,
    String? busNumber,
    String? apiBusNumber,
    String? routeType,
    String? startStop,
    String? endStop,
    String? viaStop,
    BusStopData? boardingStop,
    BusStopData? destinationStop,
    String? matchedStop,
    int? boardingOrder,
    int? destinationOrder,
    int? stopsBetween,
    int? remainingStops,
    int? arrivalMinutes,
    String? vehicleType,
    String? firstBusTime,
    String? lastBusTime,
    int? weekdayIntervalMinutes,
    int? saturdayIntervalMinutes,
    int? sundayIntervalMinutes,
    bool? dataComplete,
    List<String>? unavailableFields,
    bool? isFavorite,
  }) {
    return BusData(
      routeId: routeId ?? this.routeId,
      cityCode: cityCode ?? this.cityCode,
      busNumber: busNumber ?? this.busNumber,
      apiBusNumber: apiBusNumber ?? this.apiBusNumber,
      routeType: routeType ?? this.routeType,
      startStop: startStop ?? this.startStop,
      endStop: endStop ?? this.endStop,
      viaStop: viaStop ?? this.viaStop,
      boardingStop: boardingStop ?? this.boardingStop,
      destinationStop: destinationStop ?? this.destinationStop,
      matchedStop: matchedStop ?? this.matchedStop,
      boardingOrder: boardingOrder ?? this.boardingOrder,
      destinationOrder: destinationOrder ?? this.destinationOrder,
      stopsBetween: stopsBetween ?? this.stopsBetween,
      remainingStops: remainingStops ?? this.remainingStops,
      arrivalMinutes: arrivalMinutes ?? this.arrivalMinutes,
      vehicleType: vehicleType ?? this.vehicleType,
      firstBusTime: firstBusTime ?? this.firstBusTime,
      lastBusTime: lastBusTime ?? this.lastBusTime,
      weekdayIntervalMinutes:
          weekdayIntervalMinutes ?? this.weekdayIntervalMinutes,
      saturdayIntervalMinutes:
          saturdayIntervalMinutes ?? this.saturdayIntervalMinutes,
      sundayIntervalMinutes:
          sundayIntervalMinutes ?? this.sundayIntervalMinutes,
      dataComplete: dataComplete ?? this.dataComplete,
      unavailableFields: unavailableFields ?? this.unavailableFields,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

/// 버스 상세 화면을 닫을 때 목록 화면으로 전달하는 결과입니다.
class BusDetailResult {
  final BusData bus;
  final String? searchBusNumber;

  const BusDetailResult({required this.bus, this.searchBusNumber});
}

// 버스 노선에 포함된 정류장 정보
class BusRouteStopData {
  final String stopId;
  final String stopName;
  final String? stopNumber;
  final int order;
  final double? latitude;
  final double? longitude;
  final String? directionCode;

  const BusRouteStopData({
    required this.stopId,
    required this.stopName,
    this.stopNumber,
    required this.order,
    this.latitude,
    this.longitude,
    this.directionCode,
  });

  factory BusRouteStopData.fromJson(Map<String, dynamic> json) =>
      BusRouteStopData(
        stopId: _stringValue(json['id'] ?? json['stop_id']) ?? '',
        stopName: _stringValue(json['name'] ?? json['stop_name']) ?? '',
        stopNumber: _stringValue(json['number'] ?? json['stop_number']),
        order: _intValue(json['order']) ?? 0,
        latitude: _doubleValue(json['latitude']),
        longitude: _doubleValue(json['longitude']),
        directionCode: _stringValue(json['direction_code']),
      );
}

class BusOverviewData {
  final List<BusStopData> stops;
  final List<BusData> routes;
  final bool arrivalInformationUnavailable;
  final bool partial;
  final int unavailableStopCount;
  final int unavailableProviderCount;
  final int unavailableArrivalProviderCount;

  const BusOverviewData({
    required this.stops,
    required this.routes,
    required this.arrivalInformationUnavailable,
    required this.partial,
    required this.unavailableStopCount,
    required this.unavailableProviderCount,
    required this.unavailableArrivalProviderCount,
  });

  factory BusOverviewData.fromJson(Map<String, dynamic> json) =>
      BusOverviewData(
        stops: (json['stops'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => BusStopData.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
        routes: (json['routes'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => BusData.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        arrivalInformationUnavailable: _boolValue(
          json['arrival_information_unavailable'],
          fallback: false,
        ),
        partial: _boolValue(json['partial'], fallback: false),
        unavailableStopCount: _intValue(json['unavailable_stop_count']) ?? 0,
        unavailableProviderCount:
            _intValue(json['unavailable_provider_count']) ?? 0,
        unavailableArrivalProviderCount:
            _intValue(json['unavailable_arrival_provider_count']) ?? 0,
      );
}

class BusSearchData {
  final String destination;
  final List<BusData> routes;
  final int searchedRouteCount;
  final int originStopCount;
  final int unavailableRouteCount;
  final int unavailableStopCount;
  final int unavailableProviderCount;
  final int incompleteResultCount;
  final int unavailableArrivalStopCount;
  final bool arrivalInformationUnavailable;
  final bool providerDiscoveryUnavailable;
  final List<String> destinationProviderCityCodes;
  final bool partial;

  const BusSearchData({
    required this.destination,
    required this.routes,
    required this.searchedRouteCount,
    required this.originStopCount,
    required this.unavailableRouteCount,
    required this.unavailableStopCount,
    required this.unavailableProviderCount,
    required this.incompleteResultCount,
    required this.unavailableArrivalStopCount,
    required this.arrivalInformationUnavailable,
    required this.providerDiscoveryUnavailable,
    required this.destinationProviderCityCodes,
    required this.partial,
  });

  factory BusSearchData.fromJson(Map<String, dynamic> json) {
    final unavailableRouteCount =
        _intValue(json['unavailable_route_count']) ?? 0;
    return BusSearchData(
      destination: _stringValue(json['destination']) ?? '',
      routes: (json['routes'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => BusData.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      searchedRouteCount: _intValue(json['searched_route_count']) ?? 0,
      originStopCount: _intValue(json['origin_stop_count']) ?? 0,
      unavailableRouteCount: unavailableRouteCount,
      unavailableStopCount: _intValue(json['unavailable_stop_count']) ?? 0,
      unavailableProviderCount:
          _intValue(json['unavailable_provider_count']) ?? 0,
      incompleteResultCount: _intValue(json['incomplete_result_count']) ?? 0,
      unavailableArrivalStopCount:
          _intValue(json['unavailable_arrival_stop_count']) ?? 0,
      arrivalInformationUnavailable: _boolValue(
        json['arrival_information_unavailable'],
        fallback: false,
      ),
      providerDiscoveryUnavailable: _boolValue(
        json['provider_discovery_unavailable'],
        fallback: false,
      ),
      destinationProviderCityCodes: _stringList(
        json['destination_provider_city_codes'],
      ),
      partial: _boolValue(json['partial'], fallback: unavailableRouteCount > 0),
    );
  }
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
  ) {
    final firstBusTime =
        _stringValue(json['first_bus_time']) ?? currentBus.firstBusTime;
    final lastBusTime =
        _stringValue(json['last_bus_time']) ?? currentBus.lastBusTime;
    final weekdayIntervalMinutes =
        _intValue(json['weekday_interval_minutes']) ??
        currentBus.weekdayIntervalMinutes;
    final saturdayIntervalMinutes =
        _intValue(json['saturday_interval_minutes']) ??
        currentBus.saturdayIntervalMinutes;
    final sundayIntervalMinutes =
        _intValue(json['sunday_interval_minutes']) ??
        currentBus.sundayIntervalMinutes;
    final unavailableFields = json.containsKey('unavailable_fields')
        ? _stringList(json['unavailable_fields'])
        : currentBus.unavailableFields;
    final boardingStop = json.containsKey('boarding_stop')
        ? _nestedStop(
            json['boarding_stop'],
            fallbackCityCode: currentBus.cityCode,
          )
        : currentBus.boardingStop;
    final destinationValue = json.containsKey('destination_stop')
        ? json['destination_stop']
        : json['matched_stop'];
    final destinationStop = destinationValue == null
        ? currentBus.destinationStop
        : _nestedStop(destinationValue, fallbackCityCode: currentBus.cityCode);
    final parsedMatchedStop = _mapValue(json['matched_stop']);

    final detailBus = BusData(
      routeId:
          _stringValue(json['id'] ?? json['route_id']) ?? currentBus.routeId,
      cityCode: _stringValue(json['city_code']) ?? currentBus.cityCode,
      busNumber:
          _stringValue(json['number'] ?? json['bus_number']) ??
          currentBus.busNumber,
      apiBusNumber:
          _stringValue(json['api_bus_number'] ?? json['api_number']) ??
          currentBus.apiBusNumber,
      routeType:
          _stringValue(json['type'] ?? json['route_type']) ??
          currentBus.routeType,
      startStop: _stringValue(json['start_stop']) ?? currentBus.startStop,
      endStop: _stringValue(json['end_stop']) ?? currentBus.endStop,
      viaStop: _stringValue(json['via_stop']) ?? currentBus.viaStop,
      boardingStop: boardingStop,
      destinationStop: destinationStop,
      matchedStop: parsedMatchedStop == null
          ? _stringValue(json['matched_stop']) ??
                destinationStop?.stopName ??
                currentBus.matchedStop
          : _stringValue(
                  parsedMatchedStop['name'] ?? parsedMatchedStop['stop_name'],
                ) ??
                destinationStop?.stopName ??
                currentBus.matchedStop,
      boardingOrder:
          _intValue(json['boarding_order']) ?? currentBus.boardingOrder,
      destinationOrder:
          _intValue(json['destination_order']) ?? currentBus.destinationOrder,
      stopsBetween: _intValue(json['stops_between']) ?? currentBus.stopsBetween,
      remainingStops:
          _intValue(json['remaining_stops']) ?? currentBus.remainingStops,
      arrivalMinutes:
          _intValue(json['arrival_minutes']) ?? currentBus.arrivalMinutes,
      vehicleType: _stringValue(json['vehicle_type']) ?? currentBus.vehicleType,
      firstBusTime: firstBusTime,
      lastBusTime: lastBusTime,
      weekdayIntervalMinutes: weekdayIntervalMinutes,
      saturdayIntervalMinutes: saturdayIntervalMinutes,
      sundayIntervalMinutes: sundayIntervalMinutes,
      dataComplete: json.containsKey('data_complete')
          ? _boolValue(json['data_complete'], fallback: currentBus.dataComplete)
          : currentBus.dataComplete,
      unavailableFields: unavailableFields,
      isFavorite: currentBus.isFavorite,
    );

    return BusDetailData(
      nearbyStop: nearbyStop,
      bus: detailBus,
      firstBusTime: firstBusTime,
      lastBusTime: lastBusTime,
      weekdayIntervalMinutes: weekdayIntervalMinutes,
      saturdayIntervalMinutes: saturdayIntervalMinutes,
      sundayIntervalMinutes: sundayIntervalMinutes,
      stops: (json['stops'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                BusRouteStopData.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
    );
  }
}