import 'package:flutter/material.dart';

import '../mock_data/home_mock_data.dart';
import '../mock_data/bus_mock_data.dart';
import '../models/bus_data.dart';
import '../models/home_data.dart';
import '../services/favorite_bus_service.dart';

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

  BusSummary _homeBus = mockBus;

  @override
  void initState() {
    super.initState();

    _loadHomeBus();
  }

  // 저장된 즐겨찾기를 반영해 메인화면에 표시할 버스 선택
  Future<void> _loadHomeBus() async {
    final favoriteRouteIds =
        await FavoriteBusService.getFavoriteRouteIds();

    final candidates = <BusData>[];

    for (final buses in mockBusListByStop.values) {
      candidates.addAll(buses);
    }

    if (candidates.isEmpty) {
      return;
    }

    candidates.sort((a, b) {
      final aFavorite =
          favoriteRouteIds.contains(a.routeId);
      final bFavorite =
          favoriteRouteIds.contains(b.routeId);

      // 즐겨찾기 버스를 우선 표시
      if (aFavorite != bFavorite) {
        return aFavorite ? -1 : 1;
      }

      // 같은 조건에서는 도착시간이 빠른 버스를 우선 표시
      final aArrival =
          a.arrivalMinutes ?? 999999;
      final bArrival =
          b.arrivalMinutes ?? 999999;

      return aArrival.compareTo(bArrival);
    });

    final selectedBus = candidates.first;
    final selectedStopName =
        _findStopNameForBus(selectedBus);

    if (!mounted) {
      return;
    }

    setState(() {
      _homeBus = BusSummary(
        stopName: selectedStopName,
        busNumber: selectedBus.busNumber,
        route: _buildHomeRouteText(selectedBus),
        arrivalTime:
            _buildHomeArrivalText(selectedBus),
      );
    });
  }

  // 선택한 버스가 어느 정류장에서 출발하는지 찾기
  String _findStopNameForBus(BusData bus) {
    for (final entry in mockBusListByStop.entries) {
      final containsBus = entry.value.any(
        (item) => item.routeId == bus.routeId,
      );

      if (!containsBus) {
        continue;
      }

      for (final stop in mockNearbyBusStops) {
        if (stop.stopId == entry.key) {
          return '정류장 : ${stop.stopName}';
        }
      }
    }

    return '정류장 정보 없음 (임시)';
  }

  // 메인 카드 노선 문구 생성
  String _buildHomeRouteText(BusData bus) {
    final start = bus.startStop;
    final end = bus.endStop;

    if (start != null && end != null) {
      return '$start → $end';
    }

    return '노선 정보 없음 (임시)';
  }

  // 메인 카드 도착시간 문구 생성
  String _buildHomeArrivalText(BusData bus) {
    if (bus.arrivalMinutes == null) {
      return '도착 정보 없음';
    }

    return '${bus.arrivalMinutes}분 후 도착 (임시)';
  }

  // 임시 안내 메시지
  // ==========================================
  void _showTemporaryMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // 버스 화면 이동
  Future<void> _goToBusScreen(
    BuildContext context,
  ) async {
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

  void _goToSettingsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _goToNewsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewsScreen()),
    );
  }

  // ==========================================
  // SOS 선택창
  // ==========================================
  void _showSosMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '긴급 도움',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  '필요한 도움을 선택해 주세요.',
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),

                const SizedBox(height: 24),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
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
                '현재 위치 : ${mockLocation.locationName}',
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
            bus: _homeBus,
            onTap: () {
              _goToBusScreen(context);
            },
          ),

          const SizedBox(height: 14),

          // 병원 카드
          // SOS 버튼은 카드 내부에서 제거됨
          HomeHospitalCard(
            hospital: mockHospital,
            onTap: () {
              _goToHospitalScreen(context);
            },
          ),

          const SizedBox(height: 14),

          // 날씨 카드
          HomeWeatherCard(
            weather: mockWeather,
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
              title : '이음',
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
                onTap: () {
                  _showTemporaryMessage(context, '음성 인식 기능은 추후 연결합니다. (임시)');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
