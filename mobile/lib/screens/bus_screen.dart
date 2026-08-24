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
import '../services/api_service.dart';

class BusScreen extends StatefulWidget {
  const BusScreen({super.key});

  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<BusData> _displayedBusList = [];
  List<BusData> _allBusList = [];
  List<BusData> _searchResults = [];
  List<BusStopData> _nearbyStops = [];
  GpsLocation? _location;
  bool _arrivalInformationUnavailable = false;
  bool _overviewArrivalInformationUnavailable = false;
  bool _overviewPartial = false;

  BusStopData? _selectedStop;

  Set<String> _favoriteRouteKeys = {};
  final Set<String> _favoriteUpdatesInProgress = {};

  bool _isSearching = false;
  bool _isRefreshing = false;
  bool _isSearchLoading = false;
  bool _favoritesOnly = false;
  String? _errorMessage;
  String? _dataWarning;
  int _loadRequestId = 0;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadNearbyStops();
  }

  Future<void> _loadNearbyStops() async {
    final requestId = ++_loadRequestId;
    ++_searchRequestId;
    setState(() {
      _isRefreshing = true;
      _isSearchLoading = false;
      _errorMessage = null;
    });
    try {
      final location = await SelectedLocationService.instance.getLocation();
      final overview = await ApiService.instance.getBusOverview(location);
      if (overview.stops.isEmpty) {
        throw const ApiException('주변 버스정류장을 찾지 못했습니다.');
      }
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _location = location;
        _nearbyStops = overview.stops;
        _selectedStop = null;
        _allBusList = overview.routes;
        _displayedBusList = _sortAndFilter(overview.routes);
        _searchResults = [];
        _isSearching = false;
        _isRefreshing = false;
        _arrivalInformationUnavailable = overview.arrivalInformationUnavailable;
        _overviewArrivalInformationUnavailable =
            overview.arrivalInformationUnavailable;
        _overviewPartial = overview.partial;
        _dataWarning = overview.partial
            ? '일부 제공기관 응답이 없어 확인된 노선만 표시합니다.'
            : null;
      });
    } catch (error) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isRefreshing = false;
        _errorMessage = error.toString();
      });
      _showTemporaryMessage(error.toString());
    }
  }

  try {
    final nearbyData =
        await ApiService.instance.getNearbyBusStops(
      latitude: _testLatitude,
      longitude: _testLongitude,
    );

    final stopsJson = nearbyData['stops'];

    if (stopsJson is! List || stopsJson.isEmpty) {
      throw const ApiException(
        '주변 버스 정류장을 찾지 못했습니다.',
      );
    }

    final stops = stopsJson
        .whereType<Map<String, dynamic>>()
        .map(BusStopData.fromJson)
        .toList();

    if (stops.isEmpty) {
      throw const ApiException(
        '주변 버스 정류장을 찾지 못했습니다.',
      );
    }

    // 서버가 가까운 순으로 반환하므로 첫 번째 정류장 선택
    final selectedStop = stops.first;

    final arrivalsData =
        await ApiService.instance.getBusArrivals(
      cityCode: selectedStop.cityCode,
      stopId: selectedStop.stopId,
    );

    final arrivalsJson = arrivalsData['arrivals'];

    final buses = arrivalsJson is List
        ? arrivalsJson
            .whereType<Map<String, dynamic>>()
            .map(BusData.fromJson)
            .toList()
        : <BusData>[];

    if (!mounted) {
      return;
    }

    setState(() {
      _nearbyStops = stops;
      _selectedStop = selectedStop;
      _displayedBusList = buses;
      _isLoading = false;
      _errorMessage = null;
    });
  } on ApiException catch (error) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = error.message;
    });
  } catch (_) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = '버스 정보를 불러오는 중 오류가 발생했습니다.';
    });
  }
}

  // 휴대폰에 저장된 버스 즐겨찾기 불러오기
  Future<void> _loadFavorites() async {
    final favoriteRouteKeys = await FavoriteBusService.getFavoriteRouteIds();

    if (!mounted) {
      return;
    }

    setState(() {
      _favoriteRouteKeys = favoriteRouteKeys;
      _displayedBusList = _sortAndFilter(
        _isSearching ? _searchResults : _allBusList,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    await _loadNearbyStops();
  }

  // 목적지 검색
  Future<void> _searchDestination() async {
    FocusScope.of(context).unfocus();
    if (_isSearchLoading) return;

    final destination = _searchController.text.trim();
    final location = _location;

    if (destination.isEmpty) {
      _showTemporaryMessage('도착지역을 입력해 주세요.');
      return;
    }
    if (location == null) {
      _showTemporaryMessage('출발 위치를 확인하고 있습니다.');
      return;
    }

    final requestId = ++_searchRequestId;
    setState(() {
      _isSearchLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.instance.searchBusRoutes(
        location,
        destination,
        originStop: _selectedStop,
      );
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isSearching = true;
        _isSearchLoading = false;
        _searchResults = result.routes;
        _displayedBusList = _sortAndFilter(result.routes);
        _arrivalInformationUnavailable = result.arrivalInformationUnavailable;
        _dataWarning = _searchWarning(result);
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isSearchLoading = false;
        _errorMessage = error.toString();
      });
      _showTemporaryMessage(error.toString());
    }
  }

  String? _searchWarning(BusSearchData result) {
    if (!result.partial) return null;
    if (result.providerDiscoveryUnavailable) {
      return '목적지 지역 코드를 확인하지 못해 현재 확인 가능한 공급기관 노선만 표시합니다.';
    }
    if (result.unavailableStopCount > 0 ||
        result.unavailableProviderCount > 0 ||
        result.unavailableRouteCount > 0 ||
        result.incompleteResultCount > 0) {
      return '일부 제공기관 응답이 없어 확인 가능한 노선만 표시합니다.';
    }
    return '일부 실시간 도착정보를 받지 못했지만 확인된 노선은 모두 표시합니다.';
  }

  List<BusData> _sortAndFilter(List<BusData> source) {
    final buses = source
        .where((bus) => !_favoritesOnly || _isFavorite(bus))
        .toList();
    buses.sort((a, b) {
      final favoriteCompare = (_isFavorite(b) ? 1 : 0).compareTo(
        _isFavorite(a) ? 1 : 0,
      );
      if (favoriteCompare != 0) return favoriteCompare;
      return (a.arrivalMinutes ?? 999999).compareTo(b.arrivalMinutes ?? 999999);
    });
    return buses;
  }

  bool _isFavorite(BusData bus) {
    return FavoriteBusService.containsRoute(
      _favoriteRouteKeys,
      routeKey: bus.routeKey,
      routeId: bus.routeId,
    );
  }

  // 검색 초기화
  void _clearSearch() {
    ++_searchRequestId;
    _searchController.clear();

    final selectedStop = _selectedStop;

    if (selectedStop == null) {
      setState(() {
        _isSearching = false;
        _displayedBusList = [];
      });
      return;
    }

    setState(() {
      _isSearching = false;
      _isSearchLoading = false;
      _searchResults = [];
      _displayedBusList = _sortAndFilter(_allBusList);
      _arrivalInformationUnavailable = _overviewArrivalInformationUnavailable;
      _dataWarning = _overviewPartial ? '일부 제공기관 응답이 없어 확인된 노선만 표시합니다.' : null;
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
    final boardingStop = bus.boardingStop ?? _selectedStop;
    if (boardingStop == null) {
      _showTemporaryMessage('승차 정류장 정보를 확인할 수 없습니다.');
      return;
    }
    final updatedBus = await Navigator.push<BusData>(
      context,
      MaterialPageRoute(
        builder: (context) => BusDetailScreen(
          stop: boardingStop,
          bus: bus.copyWith(isFavorite: _isFavorite(bus)),
        ),
      ),
    );
    _searchFocusNode.unfocus();
    if (updatedBus == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (updatedBus.isFavorite) {
        _favoriteRouteKeys
          ..remove(updatedBus.routeId)
          ..add(updatedBus.routeKey);
      } else {
        _favoriteRouteKeys
          ..remove(updatedBus.routeId)
          ..remove(updatedBus.routeKey);
      }

      _displayedBusList = _sortAndFilter(
        _isSearching ? _searchResults : _allBusList,
      );
    });
  }

  // 버스 즐겨찾기 추가/해제
  Future<void> _toggleFavorite(BusData bus) async {
    if (!_favoriteUpdatesInProgress.add(bus.routeKey)) return;
    setState(() {});

    try {
      final isFavorite = await FavoriteBusService.toggleFavorite(
        bus.routeKey,
        legacyRouteId: bus.routeId,
      );

      if (!mounted) return;
      setState(() {
        if (isFavorite) {
          _favoriteRouteKeys
            ..remove(bus.routeId)
            ..add(bus.routeKey);
        } else {
          _favoriteRouteKeys
            ..remove(bus.routeId)
            ..remove(bus.routeKey);
        }
        _displayedBusList = _sortAndFilter(
          _isSearching ? _searchResults : _allBusList,
        );
      });
    } catch (error) {
      if (mounted) _showTemporaryMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _favoriteUpdatesInProgress.remove(bus.routeKey));
      } else {
        _favoriteUpdatesInProgress.remove(bus.routeKey);
      }
    }
  }

  // 주변 정류장 선택창
  void _showStopSelectionMenu() {
    if (_nearbyStops.isEmpty) {
      _showTemporaryMessage(
        '선택할 수 있는 주변 정류장이 없습니다.',
      );
      return;
    }

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
                  '검색 출발 정류장',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                  const SizedBox(height: 8),

                const Text(
                  '전체 주변 정류장 또는 한 정류장을 선택해 주세요.',
                  style: TextStyle(fontSize: 17, color: Colors.black54),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  height: 420,
                  child: ListView.builder(
                    itemCount: _nearbyStops.length + 1,
                    itemBuilder: (_, index) {
                      if (index == 0) {
                        return ListTile(
                          leading: Icon(
                            _selectedStop == null
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          title: const Text(
                            '주변 정류장 전체',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text('${_nearbyStops.length}개 정류장'),
                          onTap: () {
                            _selectOriginStop(null);
                            Navigator.pop(bottomSheetContext);
                          },
                        );
                      }
                      final stop = _nearbyStops[index - 1];
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
                          _selectOriginStop(stop);
                          Navigator.pop(bottomSheetContext);
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

  void _selectOriginStop(BusStopData? stop) {
    ++_searchRequestId;
    _searchController.clear();
    setState(() {
      _selectedStop = stop;
      _isSearching = false;
      _isSearchLoading = false;
      _searchResults = [];
      _displayedBusList = _sortAndFilter(_allBusList);
      _arrivalInformationUnavailable = _overviewArrivalInformationUnavailable;
      _dataWarning = _overviewPartial ? '일부 제공기관 응답이 없어 확인된 노선만 표시합니다.' : null;
    });
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
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildLocationSection(),
                          const SizedBox(height: 18),
                          _buildSearchSection(),
                          const SizedBox(height: 24),
                          _buildNearbyStopSection(),
                          const SizedBox(height: 20),
                          if (_nearbyStops.any(
                            (stop) => stop.stopName.contains('터미널'),
                          )) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
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
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '실시간 도착정보는 제공되지 않아 운행 노선만 표시합니다.',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_dataWarning != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _dataWarning!,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ]),
                      ),
                    ),
                    _buildBusList(),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      sliver: SliverToBoxAdapter(child: _buildHomeButton()),
                    ),
                  ],
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
                enabled: !_isSearchLoading,
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
                onPressed: _isSearchLoading ? null : _searchDestination,
                child: _isSearchLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '검색',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
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

  // 목적지 검색에 사용할 출발 정류장 영역
  Widget _buildNearbyStopSection() {
    final selectedStop = _selectedStop;

    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black12,
          ),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 12),
            Text(
              '가까운 정류장을 찾고 있습니다.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (selectedStop == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black12,
          ),
        ),
        child: const Text(
          '가까운 정류장 정보가 없습니다.',
          style: TextStyle(
            fontSize: 18,
            color: Colors.black54,
          ),
        ),
      );
    }

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
                  const Text(
                    '검색 출발 정류장',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedStop?.stopName ?? '주변 정류장 전체',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedStop == null
                        ? '${_nearbyStops.length}개 정류장 · 반경 500m'
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
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_errorMessage != null && _allBusList.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: Center(
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
          ),
        ),
      );
    }
    if (_displayedBusList.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            children: [
              const Icon(
                Icons.directions_bus_outlined,
                size: 48,
                color: Colors.black38,
              ),
              const SizedBox(height: 12),
              Text(
                _favoritesOnly
                    ? '즐겨찾기한 버스가 없습니다.'
                    : _isSearching
                    ? '목적지를 지나는 버스를 찾지 못했습니다.'
                    : '이 정류장을 지나는 버스가 없습니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    final routeNumberCounts = <String, int>{};
    for (final bus in _displayedBusList) {
      routeNumberCounts.update(
        bus.busNumber,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final bus = _displayedBusList[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == _displayedBusList.length - 1 ? 0 : 14,
            ),
            child: BusListCard(
              bus: bus.copyWith(isFavorite: _isFavorite(bus)),
              onTap: () => _openBusDetail(bus),
              onFavoriteTap: _favoriteUpdatesInProgress.contains(bus.routeKey)
                  ? null
                  : () => _toggleFavorite(bus),
              boardingStopName: bus.boardingStop?.stopName,
              boardingStopDistanceM: bus.boardingStop?.distanceM,
              showRouteIdentifier: (routeNumberCounts[bus.busNumber] ?? 0) > 1,
            ),
          );
        }, childCount: _displayedBusList.length),
      ),
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
