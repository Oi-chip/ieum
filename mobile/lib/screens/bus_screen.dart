import 'package:flutter/material.dart';

import '../mock_data/bus_mock_data.dart';
import '../models/bus_data.dart';
import '../services/favorite_bus_service.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/bus_list_card.dart';
import '../widgets/voice_button.dart';
import 'bus_detail_screen.dart';

import '../widgets/sos_menu.dart';
import '../services/api_service.dart';

class BusScreen extends StatefulWidget {
  const BusScreen({super.key});

  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  final TextEditingController _searchController = TextEditingController();

  // GPS 연결 전 사용하는 봉화 테스트 좌표
  static const double _testLatitude = 36.8931;
  static const double _testLongitude = 128.7325;

  List<BusData> _displayedBusList = [];
  List<BusStopData> _nearbyStops = [];

  BusStopData? _selectedStop;

  Set<String> _favoriteRouteIds = {};

  bool _isSearching = false;
  bool _isRefreshing = false;
  bool _wasStopAutomaticallyChanged = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadFavorites();
    _loadBusData();
  }

  // 실제 서버에서 가까운 정류장과 버스 도착정보 불러오기
Future<void> _loadBusData() async {
  if (mounted) {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
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
    final favoriteRouteIds =
        await FavoriteBusService.getFavoriteRouteIds();

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

  // 아직 구현되지 않은 기능의 임시 안내 메시지
  void _showTemporaryMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // 목적지 검색으로 정류장이 변경되었을 때 안내
  void _showStopChangedMessage() {
    final selectedStop = _selectedStop;

    if (selectedStop == null) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
            title: Row(
              children: [
                const Expanded(
                  child: Text(
                    '주의',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  icon: const Icon(
                    Icons.close,
                    size: 30,
                  ),
                  tooltip: '닫기',
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 70,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  '정류장이\n'
                  '${selectedStop.stopName} (으)로\n'
                  '변경되었습니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 버스 정보 새로고침
  Future<void> _refreshBusData() async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _loadBusData();

      if (!mounted) {
        return;
      }

      setState(() {
        _isSearching = false;
        _searchController.clear();
      });

      _showTemporaryMessage(
        '버스 정보를 새로고침했습니다.',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showTemporaryMessage(
        error.message,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // 목적지 검색
  Future<void> _searchDestination() async {
    FocusScope.of(context).unfocus();

    final destination = _searchController.text.trim();

    if (destination.isEmpty) {
      _showTemporaryMessage(
        '도착지역을 입력해 주세요.',
      );
      return;
    }

    final previousStopId = _selectedStop?.stopId;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final searchData = await ApiService.instance.searchBuses(
        latitude: _testLatitude,
        longitude: _testLongitude,
        destination: destination,
      );

      final stopJson = searchData['stop'];
      final busesJson = searchData['buses'];

      BusStopData? matchedStop;

      if (stopJson is Map<String, dynamic>) {
        matchedStop = BusStopData.fromJson(stopJson);
      }

      final matchedBuses = busesJson is List
          ? busesJson
              .whereType<Map<String, dynamic>>()
              .map(BusData.fromJson)
              .toList()
          : <BusData>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _isSearching = true;
        _displayedBusList = matchedBuses;
        _isLoading = false;

        if (matchedStop != null) {
          _wasStopAutomaticallyChanged =
              previousStopId != null &&
              matchedStop.stopId != previousStopId;

          _selectedStop = matchedStop;
        } else {
          _wasStopAutomaticallyChanged = false;
        }
      });

      if (_wasStopAutomaticallyChanged) {
        _showStopChangedMessage();
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });

      _showTemporaryMessage(
        error.message,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '버스를 검색하는 중 오류가 발생했습니다.';
      });
    }
  }

  // 검색 초기화
  Future<void> _clearSearch() async {
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
      _isLoading = true;
      _errorMessage = null;
    });

    try {
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
        _displayedBusList = buses;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    }
  }

  // 버스 카드 선택
  Future<void> _openBusDetail(BusData bus) async {
    final updatedBus = await Navigator.push<BusData>(
      context,
      MaterialPageRoute(
        builder: (context) => BusDetailScreen(
          bus: bus.copyWith(
            isFavorite: _favoriteRouteIds.contains(
              bus.routeId,
            ),
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
    final isFavorite =
        await FavoriteBusService.toggleFavorite(bus.routeId);

    if (!mounted) {
      return;
    }

    setState(() {
      if (isFavorite) {
        _favoriteRouteIds.add(bus.routeId);
      } else {
        _favoriteRouteIds.remove(bus.routeId);
      }
    });
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
          child: FractionallySizedBox(
            heightFactor: 0.75,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    '다른 정류장 선택',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    '이용할 정류장을 선택해 주세요.',
                    style: TextStyle(
                      fontSize: 17,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Expanded(
                    child: ListView.separated(
                      itemCount: _nearbyStops.length,
                      separatorBuilder: (context, index) {
                        return const Divider(
                          height: 1,
                        );
                      },
                      itemBuilder: (context, index) {
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
                          subtitle: Text(
                            '${stop.distanceM}m',
                          ),
                          onTap: () async {
                            Navigator.pop(
                              bottomSheetContext,
                            );

                            await _selectStop(stop);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectStop(BusStopData stop) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final arrivalsData =
          await ApiService.instance.getBusArrivals(
        cityCode: stop.cityCode,
        stopId: stop.stopId,
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
        _selectedStop = stop;
        _displayedBusList = buses;
        _isSearching = false;
        _searchController.clear();
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });

      _showTemporaryMessage(error.message);
    }
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
              onSettingsTap: () {
                _showTemporaryMessage(
                  '설정 화면은 B팀과 연계 예정입니다. (임시)',
                );
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
        const Icon(
          Icons.location_on,
          size: 26,
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            '현재 위치 : 봉화읍 (임시)',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _isRefreshing ? null : _refreshBusData,
          icon: _isRefreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.refresh,
                  size: 23,
                ),
          label: const Text(
            '새로고침',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
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
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
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
                  prefixIcon: const Icon(
                    Icons.search,
                  ),
                  suffixIcon: _isSearching
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(
                            Icons.close,
                          ),
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
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        ],
      ],
    );
  }

  // 가까운 정류장 영역
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
          border: Border.all(
            color: Colors.black12,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '가까운 정류장',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedStop.stopName,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${selectedStop.distanceM}m',
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }

  // 버스 목록
  Widget _buildBusList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 40,
        ),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 32,
          horizontal: 20,
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.black38,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadBusData,
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
        padding: const EdgeInsets.symmetric(
          vertical: 40,
          horizontal: 20,
        ),
        child: const Column(
          children: [
            Icon(
              Icons.directions_bus_outlined,
              size: 48,
              color: Colors.black38,
            ),
            SizedBox(height: 12),
            Text(
              '목적지를 지나는 버스를 찾지 못했습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int index = 0;
            index < _displayedBusList.length;
            index++) ...[
          BusListCard(
            bus: _displayedBusList[index].copyWith(
              isFavorite: _favoriteRouteIds.contains(
                _displayedBusList[index].routeId,
              ),
            ),
            onTap: () {
              _openBusDetail(
                _displayedBusList[index],
              );
            },
            onFavoriteTap: () {
              _toggleFavorite(
                _displayedBusList[index],
              );
            },
          ),
          if (index != _displayedBusList.length - 1)
            const SizedBox(height: 14),
        ],
      ],
    );
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
        icon: const Icon(
          Icons.home_outlined,
          size: 26,
        ),
        label: const Text(
          '홈 화면으로',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: const BorderSide(
            color: Color(0xFF90CAF9),
            width: 2,
          ),
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
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16,
      ),
      color: const Color(0xFFF8FAFC),
      child: VoiceButton(
        onTap: () {
          _showTemporaryMessage(
            '음성 인식 기능은 추후 연결합니다. (임시)',
          );
        },
      ),
    );
  }

}