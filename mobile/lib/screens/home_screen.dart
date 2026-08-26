import 'dart:async';

import 'package:flutter/material.dart';

import '../models/bus_data.dart';
import '../models/gps_location.dart';
import '../models/home_data.dart';
import '../services/api_service.dart';
import '../services/favorite_bus_service.dart';
import '../services/selected_location_service.dart';
import '../services/tts_service.dart';
import '../utils/korea_date.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/hold_to_speak.dart';
import '../widgets/home_bus_card.dart';
import '../widgets/home_hospital_card.dart';
import '../widgets/home_weather_card.dart';
import '../widgets/sos_menu.dart';
import '../widgets/voice_button.dart';
import 'bus_screen.dart';
import 'hospital_screen.dart';
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
      final location =
          await SelectedLocationService.instance.getLocation(
        requireRegion: true,
      );

      final grid =
          SelectedLocationService.instance.weatherGrid(
        location,
      );

      if (!mounted || requestId != _homeLoadRequestId) {
        return;
      }

      setState(() {
        _locationName = location.displayName;
      });

      final errors = <Object>[];

      await Future.wait<void>([
        _loadBusSection(
          location,
          requestId,
          errors,
        ),
        _loadHospitalSection(
          location,
          requestId,
          errors,
        ),
        _loadWeatherSection(
          location,
          grid,
          requestId,
          errors,
        ),
      ]);

      if (!mounted ||
          requestId != _homeLoadRequestId ||
          errors.isEmpty) {
        return;
      }

      _showTemporaryMessage(
        context,
        errors.first.toString(),
      );
    } catch (error) {
      if (!mounted || requestId != _homeLoadRequestId) {
        return;
      }

      setState(() {
        _homeBus = null;
      });

      _showTemporaryMessage(
        context,
        error.toString(),
      );
    }
  }

  Future<void> _loadBusSection(
    GpsLocation location,
    int requestId,
    List<Object> errors,
  ) async {
    try {
      final overview =
          await ApiService.instance.getBusOverview(
        location,
      );

      final homeBus = overview.stops.isNotEmpty
          ? await _buildHomeBus(
              overview.stops.first,
              overview.routes,
            )
          : null;

      if (!mounted || requestId != _homeLoadRequestId) {
        return;
      }

      setState(() {
        _homeBus = homeBus;
      });
    } catch (error) {
      if (!mounted || requestId != _homeLoadRequestId) {
        return;
      }

      errors.add(error);

      setState(() {
        _homeBus = null;
      });
    }
  }

  Future<void> _loadHospitalSection(
    GpsLocation location,
    int requestId,
    List<Object> errors,
  ) async {
    try {
      final hospitals =
          await ApiService.instance.getNearbyHospitals(
        location,
      );

      if (!mounted || requestId != _homeLoadRequestId) {
        return;
      }

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
          distance:
              '${hospital.distanceKm.toStringAsFixed(1)}km',
        );
      });
    } catch (error) {
      if (!mounted || requestId != _homeLoadRequestId) {
        return;
      }

      errors.add(error);
    }
  }

  Future<void> _loadWeatherSection(
    GpsLocation location,
    WeatherGrid grid,
    int requestId,
    List<Object> errors,
  ) async {
    try {
      final weather =
          await ApiService.instance.getWeather(
        koreaToday(),
        nx: grid.nx,
        ny: grid.ny,
      );

      final current =
          weather['current'] as Map<String, dynamic>? ??
              {};

      if (!mounted || requestId != _homeLoadRequestId) {
        return;
      }

      setState(() {
        _homeWeather = WeatherSummary(
          temperature:
              '${(current['temperature_c'] as num?)?.round() ?? '-'}°C',
          condition:
              current['condition']?.toString() ??
                  '정보 없음',
        );
      });
    } catch (error) {
      if (!mounted || requestId != _homeLoadRequestId) {
        return;
      }

      errors.add(error);
    }
  }

  Future<void> _loadHomeBus() async {
    await _loadHomeData();
  }

  Future<BusSummary?> _buildHomeBus(
    BusStopData stop,
    List<BusData> candidates,
  ) async {
    if (candidates.isEmpty) {
      return null;
    }

    final favoriteRouteKeys =
        await FavoriteBusService.getFavoriteRouteIds();

    final sortedCandidates =
        List<BusData>.of(candidates)
          ..sort((a, b) {
            final aFavorite =
                FavoriteBusService.containsRoute(
              favoriteRouteKeys,
              routeKey: a.routeKey,
              routeId: a.routeId,
            );

            final bFavorite =
                FavoriteBusService.containsRoute(
              favoriteRouteKeys,
              routeKey: b.routeKey,
              routeId: b.routeId,
            );

            if (aFavorite != bFavorite) {
              return aFavorite ? -1 : 1;
            }

            final aArrival =
                a.arrivalMinutes ?? 999999;
            final bArrival =
                b.arrivalMinutes ?? 999999;

            return aArrival.compareTo(
              bArrival,
            );
          });

    final selectedBus = sortedCandidates.first;

    final boardingStop =
        selectedBus.boardingStop ?? stop;

    return BusSummary(
      stopName:
          '정류장 : ${boardingStop.stopName}',
      busNumber: selectedBus.busNumber,
      route: _buildHomeRouteText(
        selectedBus,
      ),
      arrivalTime: _buildHomeArrivalText(
        selectedBus,
      ),
    );
  }

  String _buildHomeRouteText(
    BusData bus,
  ) {
    final start = bus.startStop;
    final end = bus.endStop;

    if (start != null && end != null) {
      if (start == end) {
        if (bus.viaStop == null) {
          return '$start 출발·도착 순환노선';
        }

        return '$start → ${bus.viaStop} → $end';
      }

      return '$start → $end';
    }

    return '노선 정보 없음';
  }

  String _buildHomeArrivalText(
    BusData bus,
  ) {
    if (bus.arrivalMinutes == null) {
      return '도착 정보 없음';
    }

    return '${bus.arrivalMinutes}분 후 도착';
  }

  void _showTemporaryMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _goToBusScreen(
    BuildContext context,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const BusScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadHomeBus();
  }

  void _goToHospitalScreen(
    BuildContext context,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const HospitalScreen(),
      ),
    );
  }

  void _goToWeatherScreen(
    BuildContext context,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const WeatherScreen(),
      ),
    );
  }

  Future<void> _goToSettingsScreen(
    BuildContext context,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const SettingsScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadHomeData();
  }

  void _handleVoiceCommand(
    BuildContext context,
    String text,
  ) {
    final command = text
        .toLowerCase()
        .replaceAll(' ', '');

    if (command.contains('긴급') ||
        command.contains('도와줘') ||
        command.contains('에스오에스') ||
        command.contains('sos')) {
      _openWithVoiceGuide(
        '긴급 도움 메뉴를 엽니다. 필요한 도움을 선택해 주세요.',
        () {
          showSosMenu(context);
        },
      );
      return;
    }

    if (command.contains('버스')) {
      _openWithVoiceGuide(
        '버스 화면으로 이동합니다.',
        () {
          _goToBusScreen(context);
        },
      );
      return;
    }

    if (command.contains('병원') ||
        command.contains('의원')) {
      _openWithVoiceGuide(
        '가까운 병원 화면으로 이동합니다.',
        () {
          _goToHospitalScreen(context);
        },
      );
      return;
    }

    if (command.contains('날씨') ||
        command.contains('기온')) {
      _openWithVoiceGuide(
        '날씨 화면으로 이동합니다.',
        () {
          _goToWeatherScreen(context);
        },
      );
      return;
    }

    if (command.contains('설정')) {
      _openWithVoiceGuide(
        '설정 화면으로 이동합니다.',
        () {
          _goToSettingsScreen(context);
        },
      );
      return;
    }

    const guide =
        '명령을 알아듣지 못했습니다. '
        '에스오에스, 설정, 버스, 병원, 날씨 중 하나를 말해 주세요.';

    _showTemporaryMessage(
      context,
      "'$text'(으)로 인식했습니다. $guide",
    );

    unawaited(
      TtsService.instance.speak(
        guide,
      ),
    );
  }

  void _openWithVoiceGuide(
    String guide,
    VoidCallback open,
  ) {
    open();

    unawaited(
      TtsService.instance.speak(
        guide,
      ),
    );
  }

  Widget _buildLocationBar() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        0,
        8,
        0,
        4,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(
              Icons.location_on,
              size: 24,
            ),

            const SizedBox(
              width: 6,
            ),

            Expanded(
              child: Text(
                '현재 위치 : $_locationName',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardList(
    BuildContext context,
  ) {
    final homeBus =
        _homeBus ?? _emptyHomeBus;

    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        3,
        16,
        16,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildLocationBar(),

          const SizedBox(
            height: 4,
          ),

          HoldToSpeak(
            text:
                '${homeBus.stopName}. '
                '${homeBus.busNumber}번 버스, '
                '${homeBus.route}. '
                '${homeBus.arrivalTime}.',
            child: HomeBusCard(
              bus: homeBus,
              onTap: () {
                _goToBusScreen(
                  context,
                );
              },
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          HoldToSpeak(
            text:
                '가까운 병원은 '
                '${_homeHospital.hospitalName}, '
                '거리는 '
                '${_homeHospital.distance}입니다.',
            child: HomeHospitalCard(
              hospital: _homeHospital,
              onTap: () {
                _goToHospitalScreen(
                  context,
                );
              },
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          HoldToSpeak(
            text:
                '현재 날씨는 '
                '${_homeWeather.condition}, '
                '기온은 '
                '${_homeWeather.temperature}입니다.',
            child: HomeWeatherCard(
              weather: _homeWeather,
              onTap: () {
                _goToWeatherScreen(
                  context,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: '이음',
              onSosTap: () {
                showSosMenu(
                  context,
                );
              },
              onSettingsTap: () {
                _goToSettingsScreen(
                  context,
                );
              },
            ),

            const Divider(
              height: 1,
            ),

            Expanded(
              child: _buildCardList(
                context,
              ),
            ),

            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16,
              ),
              decoration:
                  const BoxDecoration(
                color:
                    _backgroundColor,
              ),
              child: VoiceButton(
                onResult: (text) {
                  _handleVoiceCommand(
                    context,
                    text,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
