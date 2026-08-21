import '../models/bus_data.dart';

// 현재 가까운 정류장 임시 데이터
const BusStopData mockNearbyBusStop = BusStopData(
  stopId: 'TSB371000038',
  cityCode: '37410',
  stopName: '봉화공용터미널 (임시)',
  stopNumber: '40600',
  distanceM: 206,
);

// 주변 정류장 임시 데이터
const List<BusStopData> mockNearbyBusStops = [
  mockNearbyBusStop,
  BusStopData(
    stopId: 'TSB371000039',
    cityCode: '37410',
    stopName: '봉화공용터미널 건너편 (임시)',
    stopNumber: '40601',
    distanceM: 238,
  ),
  BusStopData(
    stopId: 'TSB371000040',
    cityCode: '37410',
    stopName: '봉화시장 (임시)',
    stopNumber: '40602',
    distanceM: 315,
  ),
];

// 정류장별 버스 목록 임시 데이터
const Map<String, List<BusData>> mockBusListByStop = {
  'TSB371000038': [
    BusData(
      routeId: 'TSB371000047',
      busNumber: '33번 (임시)',
      routeType: '농어촌(일반)버스 (임시)',
      startStop: '봉화공용터미널 (임시)',
      endStop: '영주터미널 (임시)',
      matchedStop: null,
      remainingStops: 3,
      arrivalMinutes: 5,
      isFavorite: true,
    ),
  ],

  'TSB371000039': [
    BusData(
      routeId: 'TSB371000048',
      busNumber: '34번 (임시)',
      routeType: '농어촌(일반)버스 (임시)',
      startStop: '봉화공용터미널 건너편 (임시)',
      endStop: '춘양 (임시)',
      matchedStop: null,
      remainingStops: 4,
      arrivalMinutes: 8,
      isFavorite: false,
    ),
  ],

  'TSB371000040': [
    BusData(
      routeId: 'TSB371000049',
      busNumber: '35번 (임시)',
      routeType: '농어촌(일반)버스 (임시)',
      startStop: '봉화시장 (임시)',
      endStop: '법전 (임시)',
      matchedStop: null,
      remainingStops: 6,
      arrivalMinutes: 12,
      isFavorite: false,
    ),
  ],
};

// 목적지 검색용 임시 데이터
const Map<String, List<String>> mockDestinationsByRoute = {
  'TSB371000047': [
    '영주',
    '영주터미널',
    '문단',
  ],
  'TSB371000048': [
    '춘양',
    '봉화병원',
  ],
  'TSB371000049': [
    '법전',
  ],
};

// 버스 목록 임시 데이터
const List<BusData> mockBusList = [
  BusData(
    routeId: 'TSB371000047',
    busNumber: '33번 (임시)',
    routeType: '농어촌(일반)버스 (임시)',
    startStop: '봉화공용터미널 (임시)',
    endStop: '영주터미널 (임시)',
    matchedStop: null,
    remainingStops: 3,
    arrivalMinutes: 5,
    isFavorite: true,
  ),
  BusData(
    routeId: 'TSB371000048',
    busNumber: '34번 (임시)',
    routeType: '농어촌(일반)버스 (임시)',
    startStop: '봉화공용터미널 (임시)',
    endStop: '춘양 (임시)',
    matchedStop: null,
    remainingStops: 6,
    arrivalMinutes: 12,
    isFavorite: false,
  ),
  BusData(
    routeId: 'TSB371000049',
    busNumber: '35번 (임시)',
    routeType: '농어촌(일반)버스 (임시)',
    startStop: '봉화공용터미널 (임시)',
    endStop: '법전 (임시)',
    matchedStop: null,
    remainingStops: null,
    arrivalMinutes: null,
    isFavorite: false,
  ),
];

// 목적지 검색 결과 임시 데이터
// 사용자가 "영주"를 검색했다고 가정
const List<BusData> mockSearchBusList = [
  BusData(
    routeId: 'TSB371000047',
    busNumber: '33번 (임시)',
    routeType: '농어촌(일반)버스 (임시)',
    startStop: '봉화공용터미널 (임시)',
    endStop: '영주터미널 (임시)',
    matchedStop: '영주터미널 (임시)',
    remainingStops: 3,
    arrivalMinutes: 5,
    isFavorite: true,
  ),
];

// 33번 버스 상세정보 임시 데이터
const BusDetailData mockBusDetail = BusDetailData(
  nearbyStop: mockNearbyBusStop,
  bus: BusData(
    routeId: 'TSB371000047',
    busNumber: '33번 (임시)',
    routeType: '농어촌(일반)버스 (임시)',
    startStop: '봉화공용터미널 (임시)',
    endStop: '영주터미널 (임시)',
    matchedStop: null,
    remainingStops: 3,
    arrivalMinutes: 5,
    isFavorite: true,
  ),
  firstBusTime: '06:20 (임시)',
  lastBusTime: '21:30 (임시)',
  weekdayIntervalMinutes: 30,
  saturdayIntervalMinutes: 40,
  sundayIntervalMinutes: 50,
  stops: [
    BusRouteStopData(
      stopId: 'STOP001',
      stopName: '봉화공용터미널 (임시)',
      stopNumber: '10001',
      order: 1,
    ),
    BusRouteStopData(
      stopId: 'STOP002',
      stopName: '봉화시장 (임시)',
      stopNumber: '10002',
      order: 2,
    ),
    BusRouteStopData(
      stopId: 'STOP003',
      stopName: '문단 (임시)',
      stopNumber: '10003',
      order: 3,
    ),
    BusRouteStopData(
      stopId: 'STOP004',
      stopName: '평은 (임시)',
      stopNumber: '10004',
      order: 4,
    ),
    BusRouteStopData(
      stopId: 'STOP005',
      stopName: '영주터미널 (임시)',
      stopNumber: '10005',
      order: 5,
    ),
  ],
);

// 선택한 버스에 맞는 상세정보 임시 데이터 반환
BusDetailData getMockBusDetail(BusData bus) {
  return BusDetailData(
    nearbyStop: mockNearbyBusStop,
    bus: bus,
    firstBusTime: '06:20 (임시)',
    lastBusTime: '21:30 (임시)',
    weekdayIntervalMinutes: 30,
    saturdayIntervalMinutes: 40,
    sundayIntervalMinutes: 50,
    stops: [
      BusRouteStopData(
        stopId: 'STOP001',
        stopName: bus.startStop ?? '출발지 (임시)',
        stopNumber: '10001',
        order: 1,
      ),
      const BusRouteStopData(
        stopId: 'STOP002',
        stopName: '봉화시장 (임시)',
        stopNumber: '10002',
        order: 2,
      ),
      const BusRouteStopData(
        stopId: 'STOP003',
        stopName: '문단 (임시)',
        stopNumber: '10003',
        order: 3,
      ),
      const BusRouteStopData(
        stopId: 'STOP004',
        stopName: '평은 (임시)',
        stopNumber: '10004',
        order: 4,
      ),
      BusRouteStopData(
        stopId: 'STOP005',
        stopName: '${bus.endStop ?? '종점'} (임시)',
        stopNumber: '10005',
        order: 5,
      ),
    ],
  );
}

