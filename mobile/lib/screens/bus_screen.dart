import 'package:flutter/material.dart';

import '../models/bus_data.dart';
import '../models/gps_location.dart';
import '../services/api_service.dart';
import '../services/favorite_bus_service.dart';
import '../services/selected_location_service.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/bus_list_card.dart';
import '../widgets/voice_button.dart';
import 'bus_detail_screen.dart';
import 'settings_screen.dart';

import '../widgets/sos_menu.dart';

class BusScreen extends StatefulWidget {
  const BusScreen({super.key});

  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _StopBusBundle {
  final BusStopData stop;
  final List<BusData> routes;
  final Map<String, BusData> arrivals;
  final bool arrivalInformationUnavailable;

  const _StopBusBundle({
    required this.stop,
    required this.routes,
    required this.arrivals,
    required this.arrivalInformationUnavailable,
  });
}

class _BusScreenState extends State<BusScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<BusData> _displayedBusList = [];
  List<BusData> _allBusList = [];
  List<BusData> _searchResults = [];
  List<BusStopData> _nearbyStops = [];
  final Map<String, BusDetailData> _routeDetails = {};
  final Map<String, BusStopData> _routeBoardingStops = {};
  GpsLocation? _location;
  bool _usesCurrentLocation = true;
  bool _arrivalInformationUnavailable = false;

  BusStopData? _selectedStop;

  Set<String> _favoriteRouteIds = {};

  bool _isSearching = false;
  bool _isRefreshing = false;
  bool _favoritesOnly = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadNearbyStops();
  }

  Future<void> _loadNearbyStops() async {
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });
    try {
      final location = await SelectedLocationService.instance.getLocation();
      final usesCurrentLocation = await SelectedLocationService.instance
          .usesCurrentLocation();
      final stops = await ApiService.instance.getNearbyBusStops(location);
      if (stops.isEmpty) throw const ApiException('주변 버스정류장을 찾지 못했습니다.');
      if (!mounted) return;
      _location = location;
      _usesCurrentLocation = usesCurrentLocation;
      _nearbyStops = stops;
      _selectedStop = _selectInitialStop(stops, usesCurrentLocation);
      _routeDetails.clear();
      _routeBoardingStops.clear();
      await _loadSelectedStopBuses();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _errorMessage = error.toString();
      });
      _showTemporaryMessage(error.toString());
    }
  }

  Future<void> _loadSelectedStopBuses() async {
    final stop = _selectedStop;
    if (stop == null) return;
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });
    try {
      final bundles = await Future.wait(
        _boardingStopsFor(stop).map(_loadStopBusBundle),
      );
      final busesByRoute = <String, BusData>{};
      final boardingStopsByRoute = <String, BusStopData>{};

      for (final bundle in bundles) {
        for (final route in bundle.routes) {
          if (!_usesCurrentLocation && !_isDepartingRoute(route, bundle.stop)) {
            continue;
          }

          final currentBoardingStop = boardingStopsByRoute[route.routeId];
          if (currentBoardingStop != null &&
              _boardingPriority(route, currentBoardingStop) >=
                  _boardingPriority(route, bundle.stop)) {
            continue;
          }

          final arrival = bundle.arrivals[route.routeId];
          busesByRoute[route.routeId] = BusData(
            routeId: route.routeId,
            cityCode: route.cityCode,
            busNumber: route.busNumber,
            routeType: route.routeType,
            startStop: route.startStop,
            endStop: route.endStop,
            remainingStops: arrival?.remainingStops,
            arrivalMinutes: arrival?.arrivalMinutes,
          );
          boardingStopsByRoute[route.routeId] = bundle.stop;
        }
      }

      final buses = busesByRoute.values.toList();
      if (!mounted) return;
      setState(() {
        _routeBoardingStops
          ..clear()
          ..addAll(boardingStopsByRoute);
        _allBusList = buses;
        _displayedBusList = _sortAndFilter(buses);
        _searchResults = [];
        _isSearching = false;
        _isRefreshing = false;
        _arrivalInformationUnavailable = bundles.every(
          (bundle) => bundle.arrivalInformationUnavailable,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _errorMessage = error.toString();
      });
      _showTemporaryMessage(error.toString());
    }
  }

  Future<_StopBusBundle> _loadStopBusBundle(BusStopData stop) async {
    final routesFuture = ApiService.instance.getStopRoutes(stop);
    var arrivals = <String, BusData>{};
    var arrivalInformationUnavailable = false;

    try {
      final arrivalList = await ApiService.instance.getBusArrivals(stop);
      arrivals = {for (final bus in arrivalList) bus.routeId: bus};
    } catch (_) {
      arrivalInformationUnavailable = true;
    }

    return _StopBusBundle(
      stop: stop,
      routes: await routesFuture,
      arrivals: arrivals,
      arrivalInformationUnavailable: arrivalInformationUnavailable,
    );
  }

  List<BusStopData> _boardingStopsFor(BusStopData selectedStop) {
    if (_usesCurrentLocation || !_isTerminalName(selectedStop.stopName)) {
      return [selectedStop];
    }

    final isBonghwa = _location?.displayName.contains('봉화') == true;
    final additionalStops = _nearbyStops.where((candidate) {
      if (candidate.stopId == selectedStop.stopId ||
          candidate.cityCode != selectedStop.cityCode ||
          candidate.distanceM > selectedStop.distanceM + 100) {
        return false;
      }
      return _isTerminalName(candidate.stopName) ||
          (isBonghwa &&
              candidate.stopName.replaceAll(' ', '').contains('삼양홈마트'));
    });

    return [selectedStop, ...additionalStops];
  }

  bool _isTerminalName(String value) {
    final name = value.replaceAll(' ', '');
    return name.contains('터미널') || name.contains('공용정류장');
  }

  bool _isDepartingRoute(BusData route, BusStopData boardingStop) {
    final start = route.startStop?.replaceAll(' ', '');
    final end = route.endStop?.replaceAll(' ', '');
    final stopName = boardingStop.stopName.replaceAll(' ', '');
    if (start == null || end == null || start == end) return true;

    final startsHere =
        start == stopName ||
        (_isTerminalName(start) && _isTerminalName(stopName));
    final endsHere =
        end == stopName || (_isTerminalName(end) && _isTerminalName(stopName));
    return !endsHere || startsHere;
  }

  int _boardingPriority(BusData route, BusStopData boardingStop) {
    final start = route.startStop?.replaceAll(' ', '');
    final stopName = boardingStop.stopName.replaceAll(' ', '');
    if (start == stopName) return 3;
    if (start != null && _isTerminalName(start) && _isTerminalName(stopName)) {
      return 2;
    }
    return boardingStop.stopId == _selectedStop?.stopId ? 1 : 0;
  }

  BusStopData _selectInitialStop(
    List<BusStopData> stops,
    bool usesCurrentLocation,
  ) {
    if (usesCurrentLocation) return stops.first;
    final terminals = stops.where((stop) {
      final name = stop.stopName.replaceAll(' ', '');
      return name.contains('터미널') || name.contains('공용정류장');
    }).toList()..sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return terminals.isEmpty ? stops.first : terminals.first;
  }

  // 휴대폰에 저장된 버스 즐겨찾기 불러오기
  Future<void> _loadFavorites() async {
    final favoriteRouteIds = await FavoriteBusService.getFavoriteRouteIds();

    if (!mounted) {
      return;
    }

    setState(() {
      _favoriteRouteIds = favoriteRouteIds;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 조회나 입력 오류를 화면 하단에 안내합니다.
  void _showTemporaryMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // 버스 정보 새로고침
  Future<void> _refreshBusData() async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    await _loadSelectedStopBuses();
  }

  // 목적지 검색
  Future<void> _searchDestination() async {
    FocusScope.of(context).unfocus();

    final destination = _searchController.text.trim();

    if (destination.isEmpty) {
      _showTemporaryMessage('도착지역을 입력해 주세요.');
      return;
    }

    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    final matches = <BusData>[];
    try {
      for (var start = 0; start < _allBusList.length; start += 4) {
        final end = start + 4 < _allBusList.length
            ? start + 4
            : _allBusList.length;
        final batch = await Future.wait(
          _allBusList
              .sublist(start, end)
              .map((bus) => _matchDestination(bus, destination)),
        );
        matches.addAll(batch.whereType<BusData>());
      }
      if (!mounted) return;
      setState(() {
        _isSearching = true;
        _isRefreshing = false;
        _searchResults = matches;
        _displayedBusList = _sortAndFilter(matches);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<BusData?> _matchDestination(BusData bus, String destination) async {
    final stop = _routeBoardingStops[bus.routeId] ?? _selectedStop;
    if (stop == null) return null;
    final normalized = destination.toLowerCase();
    final routeNumberMatch = bus.busNumber.toLowerCase().contains(normalized);
    final endStopMatch =
        bus.endStop?.toLowerCase().contains(normalized) == true;
    BusDetailData detail;
    try {
      detail =
          _routeDetails[bus.routeId] ??
          await ApiService.instance.getBusRoute(stop, bus);
    } catch (_) {
      if (!routeNumberMatch && !endStopMatch) return null;
      return BusData(
        routeId: bus.routeId,
        cityCode: bus.cityCode,
        busNumber: bus.busNumber,
        routeType: bus.routeType,
        startStop: bus.startStop,
        endStop: bus.endStop,
        viaStop: bus.viaStop,
        matchedStop: bus.endStop ?? destination,
        remainingStops: bus.remainingStops,
        arrivalMinutes: bus.arrivalMinutes,
      );
    }
    _routeDetails[bus.routeId] = detail;
    final boardingIndex = detail.stops.indexWhere(
      (item) => item.stopId == stop.stopId,
    );
    final destinationStops = boardingIndex < 0
        ? detail.stops
        : detail.stops.skip(boardingIndex + 1);
    String? matchedStop;
    for (final item in destinationStops) {
      if (item.stopName.toLowerCase().contains(normalized)) {
        matchedStop = item.stopName;
        break;
      }
    }
    if (matchedStop == null && !routeNumberMatch && !endStopMatch) return null;
    return BusData(
      routeId: bus.routeId,
      cityCode: bus.cityCode,
      busNumber: bus.busNumber,
      routeType: bus.routeType,
      startStop: detail.bus.startStop ?? bus.startStop,
      endStop: detail.bus.endStop ?? bus.endStop,
      viaStop: detail.bus.viaStop,
      matchedStop: matchedStop ?? bus.endStop ?? destination,
      remainingStops: bus.remainingStops,
      arrivalMinutes: bus.arrivalMinutes,
    );
  }

  List<BusData> _sortAndFilter(List<BusData> source) {
    final buses = source
        .where(
          (bus) => !_favoritesOnly || _favoriteRouteIds.contains(bus.routeId),
        )
        .toList();
    buses.sort((a, b) {
      final favoriteCompare = (_favoriteRouteIds.contains(b.routeId) ? 1 : 0)
          .compareTo(_favoriteRouteIds.contains(a.routeId) ? 1 : 0);
      if (favoriteCompare != 0) return favoriteCompare;
      return (a.arrivalMinutes ?? 999999).compareTo(b.arrivalMinutes ?? 999999);
    });
    return buses;
  }

  // 검색 초기화
  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _isSearching = false;

      _searchResults = [];
      _displayedBusList = _sortAndFilter(_allBusList);
    });
  }

  // 버스 화면 음성 명령 처리
  void _handleVoiceCommand(String text) {
    final command = text.toLowerCase().replaceAll(' ', '');

    if (command.contains('뒤로') ||
        command.contains('홈') ||
        command.contains('나가기')) {
      Navigator.pop(context);
      return;
    }

    if (command.contains('새로고침') || command.contains('갱신')) {
      _refreshBusData();
      return;
    }

    final destination = text
        .replaceAll(
          RegExp(r'(버스|도착\s*지역|목적지|가는|가려는|검색해\s*줘|검색|찾아\s*줘|알려\s*줘|보여\s*줘)'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (destination.isEmpty) {
      _showTemporaryMessage('찾을 목적지를 말해 주세요.');
      return;
    }

    _searchController.text = destination;
    _searchDestination();
  }

  // 버스 카드 선택
  Future<void> _openBusDetail(BusData bus) async {
    final updatedBus = await Navigator.push<BusData>(
      context,
      MaterialPageRoute(
        builder: (context) => BusDetailScreen(
          stop: _routeBoardingStops[bus.routeId] ?? _selectedStop!,
          bus: bus.copyWith(
            isFavorite: _favoriteRouteIds.contains(bus.routeId),
          ),
        ),
      ),
    );

    if (updatedBus == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (updatedBus.isFavorite) {
        _favoriteRouteIds.add(updatedBus.routeId);
      } else {
        _favoriteRouteIds.remove(updatedBus.routeId);
      }

      _displayedBusList = _displayedBusList.map((item) {
        if (item.routeId == updatedBus.routeId) {
          return updatedBus;
        }

        return item;
      }).toList();
    });
  }

  // 버스 즐겨찾기 추가/해제
  Future<void> _toggleFavorite(BusData bus) async {
    final isFavorite = await FavoriteBusService.toggleFavorite(bus.routeId);

    if (!mounted) {
      return;
    }

    setState(() {
      if (isFavorite) {
        _favoriteRouteIds.add(bus.routeId);
      } else {
        _favoriteRouteIds.remove(bus.routeId);
      }
      _displayedBusList = _sortAndFilter(
        _isSearching ? _searchResults : _allBusList,
      );
    });
  }

  // 주변 정류장 선택창
  void _showStopSelectionMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '다른 정류장 선택',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  '이용할 정류장을 선택해 주세요.',
                  style: TextStyle(fontSize: 17, color: Colors.black54),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  height: 420,
                  child: ListView.builder(
                    itemCount: _nearbyStops.length,
                    itemBuilder: (_, index) {
                      final stop = _nearbyStops[index];
                      return ListTile(
                        leading: Icon(
                          stop.stopId == _selectedStop?.stopId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        title: Text(
                          stop.stopName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(_distanceText(stop.distanceM)),
                        onTap: () {
                          setState(() => _selectedStop = stop);
                          Navigator.pop(bottomSheetContext);
                          _searchController.clear();
                          _routeDetails.clear();
                          _loadSelectedStopBuses();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: '버스',
              onSosTap: () {
                showSosMenu(context);
              },
              onSettingsTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                if (mounted) await _loadNearbyStops();
              },
            ),

            const Divider(height: 1),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshBusData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLocationSection(),

                      const SizedBox(height: 18),

                      _buildSearchSection(),

                      const SizedBox(height: 24),

                      _buildNearbyStopSection(),

                      const SizedBox(height: 20),

                      if (_selectedStop?.stopName.contains('터미널') == true) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '아래 정보는 농어촌버스 운행 노선입니다. 시외버스 시간표는 포함되지 않습니다.',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      _buildListControls(),

                      const SizedBox(height: 12),

                      if (_arrivalInformationUnavailable) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '실시간 도착정보는 제공되지 않아 운행 노선만 표시합니다.',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      _buildBusList(),

                      const SizedBox(height: 24),

                      _buildHomeButton(),
                    ],
                  ),
                ),
              ),
            ),

            _buildVoiceButton(),
          ],
        ),
      ),
    );
  }

  // 현재 위치와 새로고침 영역
  Widget _buildLocationSection() {
    return Row(
      children: [
        const Icon(Icons.location_on, size: 26),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '조회 지역 : ${_location?.displayName ?? '확인 중'}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton.icon(
          onPressed: _isRefreshing ? null : _refreshBusData,
          icon: _isRefreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 23),
          label: const Text(
            '새로고침',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // 도착지역 검색 영역
  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '도착지역 검색',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  _searchDestination();
                },
                decoration: InputDecoration(
                  hintText: '예: 영주, 춘양, 봉화병원',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _searchDestination,
                child: const Text(
                  '검색',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        if (_isSearching) ...[
          const SizedBox(height: 10),
          Text(
            "'${_searchController.text.trim()}' 목적지 검색 결과",
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ],
      ],
    );
  }

  // 가까운 정류장 영역
  Widget _buildNearbyStopSection() {
    return InkWell(
      onTap: _showStopSelectionMenu,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _usesCurrentLocation ? '가까운 정류장' : '지역 대표 정류장',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedStop?.stopName ?? '정류장 확인 중',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedStop == null
                        ? '거리 확인 중'
                        : _distanceText(_selectedStop!.distanceM),
                    style: const TextStyle(fontSize: 17, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 30),
          ],
        ),
      ),
    );
  }

  // 버스 목록
  Widget _buildBusList() {
    if (_isRefreshing && _allBusList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null && _allBusList.isEmpty) {
      return Center(
        child: Column(
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadNearbyStops,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (_displayedBusList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            Icon(
              Icons.directions_bus_outlined,
              size: 48,
              color: Colors.black38,
            ),
            SizedBox(height: 12),
            Text(
              _favoritesOnly
                  ? '즐겨찾기한 버스가 없습니다.'
                  : _isSearching
                  ? '목적지를 지나는 버스를 찾지 못했습니다.'
                  : '이 정류장을 지나는 버스가 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int index = 0; index < _displayedBusList.length; index++) ...[
          BusListCard(
            bus: _displayedBusList[index].copyWith(
              isFavorite: _favoriteRouteIds.contains(
                _displayedBusList[index].routeId,
              ),
            ),
            onTap: () {
              _openBusDetail(_displayedBusList[index]);
            },
            onFavoriteTap: () {
              _toggleFavorite(_displayedBusList[index]);
            },
            boardingStopName:
                _routeBoardingStops[_displayedBusList[index].routeId]?.stopId ==
                    _selectedStop?.stopId
                ? null
                : _routeBoardingStops[_displayedBusList[index].routeId]
                      ?.stopName,
            boardingStopDistanceM:
                _routeBoardingStops[_displayedBusList[index].routeId]?.stopId ==
                    _selectedStop?.stopId
                ? null
                : _routeBoardingStops[_displayedBusList[index].routeId]
                      ?.distanceM,
            showRouteIdentifier:
                _displayedBusList
                    .where(
                      (bus) =>
                          bus.busNumber == _displayedBusList[index].busNumber,
                    )
                    .length >
                1,
          ),
          if (index != _displayedBusList.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildListControls() {
    return Row(
      children: [
        Text(
          _isSearching
              ? '검색 결과 ${_displayedBusList.length}개'
              : '운행 버스 ${_displayedBusList.length}개',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        FilterChip(
          selected: _favoritesOnly,
          avatar: const Icon(Icons.star, size: 18),
          label: const Text('즐겨찾기만'),
          onSelected: (selected) {
            setState(() {
              _favoritesOnly = selected;
              _displayedBusList = _sortAndFilter(
                _isSearching ? _searchResults : _allBusList,
              );
            });
          },
        ),
      ],
    );
  }

  String _distanceText(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  // 홈 화면으로 돌아가는 버튼
  Widget _buildHomeButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: const Icon(Icons.home_outlined, size: 26),
        label: const Text(
          '홈 화면으로',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: const BorderSide(color: Color(0xFF90CAF9), width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // 공통 음성인식 버튼
  Widget _buildVoiceButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: const Color(0xFFF8FAFC),
      child: VoiceButton(onResult: _handleVoiceCommand),
    );
  }
}
