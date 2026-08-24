import 'package:flutter/material.dart';

import '../mock_data/home_mock_data.dart';
import '../models/bus_data.dart';
import '../models/gps_location.dart';
import '../models/home_data.dart';
import '../services/api_service.dart';
import '../services/favorite_bus_service.dart';
import '../services/selected_location_service.dart';

import '../widgets/app_top_bar.dart';
import '../widgets/home_bus_card.dart';
import '../widgets/home_hospital_card.dart';
import '../widgets/home_news_card.dart';
import '../widgets/home_weather_card.dart';
import '../widgets/sos_menu.dart';
import '../widgets/voice_button.dart';

import 'bus_screen.dart';
import 'hospital_screen.dart';
import 'news_screen.dart';
import 'settings_screen.dart';
import 'weather_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _backgroundColor = Color(0xFFF8FAFC);
  static const BusSummary _emptyHomeBus = BusSummary(
    stopName: '주변 정류장',
    busNumber: '-',
    route: '현재 확인된 운행 버스가 없습니다.',
    arrivalTime: '버스 목록에서 다시 확인해 주세요.',
  );

  BusSummary? _homeBus = const BusSummary(
    stopName: '정류장 확인 중',
    busNumber: '-',
    route: '노선 정보를 불러오는 중입니다.',
    arrivalTime: '도착 정보 확인 중',
  );
  HospitalSummary _homeHospital = const HospitalSummary(
    hospitalName: '가까운 병원 확인 중',
    distance: '-',
  );
  WeatherSummary _homeWeather = const WeatherSummary(
    temperature: '-',
    condition: '날씨 확인 중',
  );
  String _locationName = '현재 위치 확인 중';
  int _homeLoadRequestId = 0;

  @override
  void initState() {
    super.initState();

    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    final requestId = ++_homeLoadRequestId;
    try {
      final location = await SelectedLocationService.instance.getLocation(
        requireRegion: true,
      );
      final grid = SelectedLocationService.instance.weatherGrid(location);
      if (!mounted || requestId != _homeLoadRequestId) return;
      setState(() => _locationName = location.displayName);

      final errors = <Object>[];
      await Future.wait<void>([
        _loadBusSection(location, requestId, errors),
        _loadHospitalSection(location, requestId, errors),
        _loadWeatherSection(location, grid, requestId, errors),
      ]);

      if (!mounted || requestId != _homeLoadRequestId || errors.isEmpty) return;
      _showTemporaryMessage(context, errors.first.toString());
    } catch (error) {
      if (mounted && requestId == _homeLoadRequestId) {
        setState(() => _homeBus = null);
        _showTemporaryMessage(context, error.toString());
      }
    }
  }

  Future<void> _loadBusSection(
    GpsLocation location,
    int requestId,
    List<Object> errors,
  ) async {
    try {
      final overview = await ApiService.instance.getBusOverview(location);
      final homeBus = overview.stops.isNotEmpty
          ? await _buildHomeBus(overview.stops.first, overview.routes)
          : null;
      if (!mounted || requestId != _homeLoadRequestId) return;
      setState(() => _homeBus = homeBus);
    } catch (error) {
      if (!mounted || requestId != _homeLoadRequestId) return;
      errors.add(error);
      setState(() => _homeBus = null);
    }
  }

  Future<void> _loadHospitalSection(
    GpsLocation location,
    int requestId,
    List<Object> errors,
  ) async {
    try {
      final hospitals = await ApiService.instance.getNearbyHospitals(location);
      if (!mounted || requestId != _homeLoadRequestId) return;
      setState(() {
        if (hospitals.isEmpty) {
          _homeHospital = const HospitalSummary(
            hospitalName: '주변 병원 없음',
            distance: '-',
          );
          return;
        }
        final hospital = hospitals.first;
        _homeHospital = HospitalSummary(
          hospitalName: hospital.hospitalName,
          distance: '${hospital.distanceKm.toStringAsFixed(1)}km',
        );
      });
    } catch (error) {
      if (mounted && requestId == _homeLoadRequestId) errors.add(error);
    }
  }

  Future<void> _loadWeatherSection(
    GpsLocation location,
    WeatherGrid grid,
    int requestId,
    List<Object> errors,
  ) async {
    try {
      final weather = await ApiService.instance.getWeather(
        DateTime.now(),
        nx: grid.nx,
        ny: grid.ny,
      );
      final current = weather['current'] as Map<String, dynamic>? ?? {};
      if (!mounted || requestId != _homeLoadRequestId) return;
      setState(() {
        _homeWeather = WeatherSummary(
          temperature:
              '${(current['temperature_c'] as num?)?.round() ?? '-'}°C',
          condition: current['condition']?.toString() ?? '정보 없음',
        );
      });
    } catch (error) {
      if (mounted && requestId == _homeLoadRequestId) errors.add(error);
    }
  }

  // 저장된 즐겨찾기를 반영해 메인화면에 표시할 버스 선택
  Future<void> _loadHomeBus() async {
    await _loadHomeData();
  }

  Future<BusSummary?> _buildHomeBus(
    BusStopData stop,
    List<BusData> candidates,
  ) async {
    if (candidates.isEmpty) return null;

    final favoriteRouteKeys = await FavoriteBusService.getFavoriteRouteIds();
    final sortedCandidates = List<BusData>.of(candidates)
      ..sort((a, b) {
        final aFavorite = FavoriteBusService.containsRoute(
          favoriteRouteKeys,
          routeKey: a.routeKey,
          routeId: a.routeId,
        );
        final bFavorite = FavoriteBusService.containsRoute(
          favoriteRouteKeys,
          routeKey: b.routeKey,
          routeId: b.routeId,
        );

        // 즐겨찾기 버스를 우선 표시
        if (aFavorite != bFavorite) {
          return aFavorite ? -1 : 1;
        }

        // 같은 조건에서는 도착시간이 빠른 버스를 우선 표시
        final aArrival = a.arrivalMinutes ?? 999999;
        final bArrival = b.arrivalMinutes ?? 999999;

        return aArrival.compareTo(bArrival);
      });

    final selectedBus = sortedCandidates.first;
    final boardingStop = selectedBus.boardingStop ?? stop;
    return BusSummary(
      stopName: '정류장 : ${boardingStop.stopName}',
      busNumber: selectedBus.busNumber,
      route: _buildHomeRouteText(selectedBus),
      arrivalTime: _buildHomeArrivalText(selectedBus),
    );
  }

  // 메인 카드 노선 문구 생성
  String _buildHomeRouteText(BusData bus) {
    final start = bus.startStop;
    final end = bus.endStop;

    if (start != null && end != null) {
      if (start == end) {
        return bus.viaStop == null
            ? '$start 출발·도착 순환노선'
            : '$start → ${bus.viaStop} → $end';
      }
      return '$start → $end';
    }

    return '노선 정보 없음';
  }

  // 메인 카드 도착시간 문구 생성
  String _buildHomeArrivalText(BusData bus) {
    if (bus.arrivalMinutes == null) {
      return '도착 정보 없음';
    }

    return '${bus.arrivalMinutes}분 후 도착';
  }

  // 임시 안내 메시지
  // ==========================================
  void _showTemporaryMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // 버스 화면 이동
  Future<void> _goToBusScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BusScreen()),
    );

    // 버스화면에서 즐겨찾기를 변경했을 수 있으므로 다시 확인
    await _loadHomeBus();
  }

  // 병원 화면 이동
  void _goToHospitalScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HospitalScreen()),
    );
  }

  void _goToWeatherScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WeatherScreen()),
    );
  }

  Future<void> _goToSettingsScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    if (mounted) await _loadHomeData();
  }

  void _goToNewsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewsScreen()),
    );
  }

  // 메인 화면 음성 명령 처리
  void _handleVoiceCommand(BuildContext context, String text) {
    final command = text.toLowerCase().replaceAll(' ', '');

    if (command.contains('긴급') ||
        command.contains('도와줘') ||
        command.contains('에스오에스')) {
      showSosMenu(context);
    } else if (command.contains('버스')) {
      _goToBusScreen(context);
    } else if (command.contains('병원') || command.contains('의원')) {
      _goToHospitalScreen(context);
    } else if (command.contains('날씨') || command.contains('기온')) {
      _goToWeatherScreen(context);
    } else if (command.contains('소식') ||
        command.contains('뉴스') ||
        command.contains('공지')) {
      _goToNewsScreen(context);
    } else if (command.contains('설정')) {
      _goToSettingsScreen(context);
    } else {
      _showTemporaryMessage(
        context,
        "'$text'(으)로 인식했습니다. 버스, 병원, 날씨, 지역 소식 또는 설정이라고 말해 주세요.",
      );
    }
  }

  // ==========================================
  // 현재 위치 표시
  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(Icons.location_on, size: 24),

            const SizedBox(width: 6),

            Expanded(
              child: Text(
                '현재 위치 : $_locationName',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 메인 카드 목록
  Widget _buildCardList(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 3, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //현재 위치
          _buildLocationBar(),
          const SizedBox(height: 4),

          // 버스 카드
          HomeBusCard(
            bus: _homeBus ?? _emptyHomeBus,
            onTap: () {
              _goToBusScreen(context);
            },
          ),

          const SizedBox(height: 14),

          // 병원 카드
          // SOS 버튼은 카드 내부에서 제거됨
          HomeHospitalCard(
            hospital: _homeHospital,
            onTap: () {
              _goToHospitalScreen(context);
            },
          ),

          const SizedBox(height: 14),

          // 날씨 카드
          HomeWeatherCard(
            weather: _homeWeather,
            onTap: () => _goToWeatherScreen(context),
          ),

          const SizedBox(height: 14),

          // 지역 소식 카드
          HomeNewsCard(
            newsList: mockNewsList,
            onTap: () => _goToNewsScreen(context),
          ),
        ],
      ),
    );
  }

  // 화면 구성
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,

      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // 공통 상단 바
            // SOS / 이음 / 설정
            // ==========================================
            AppTopBar(
              title: '이음',
              onSosTap: () {
                showSosMenu(context);
              },
              onSettingsTap: () {
                _goToSettingsScreen(context);
              },
            ),

            const Divider(height: 1),

            // 메인 카드 영역
            Expanded(child: _buildCardList(context)),

            // 공통 음성 인식 버튼
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(color: _backgroundColor),
              child: VoiceButton(
                onResult: (text) => _handleVoiceCommand(context, text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
