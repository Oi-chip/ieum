import 'package:flutter/material.dart';

import '../mock_data/bus_mock_data.dart';
import '../models/bus_data.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/bus_list_card.dart';
import '../widgets/voice_button.dart';
import 'bus_detail_screen.dart';

import '../widgets/sos_menu.dart';

class BusScreen extends StatefulWidget {
  const BusScreen({super.key});

  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<BusData> _displayedBusList = List.from(mockBusList);

  late BusStopData _selectedStop;

  bool _isSearching = false;
  bool _isRefreshing = false;
  bool _wasStopAutomaticallyChanged = false;

  @override
  void initState() {
    super.initState();
    _selectedStop = mockNearbyBusStop;
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
                  '${_selectedStop.stopName} (으)로\n'
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

    // 실제 API 연결 전 새로고침 동작을 확인하기 위한 임시 지연
    await Future.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _displayedBusList = List.from(mockBusList);
      _isSearching = false;
      _searchController.clear();
      _isRefreshing = false;
    });

    _showTemporaryMessage(
      '버스 정보를 새로고침했습니다. 현재는 임시 데이터입니다.',
    );
  }

  // 목적지 검색
  void _searchDestination() {
    FocusScope.of(context).unfocus();

    final destination = _searchController.text.trim();

    if (destination.isEmpty) {
      _showTemporaryMessage(
        '도착지역을 입력해 주세요.',
      );
      return;
    }

    BusStopData? matchedStop;
    List<BusData> matchedBuses = [];

    // 현재 선택 정류장을 먼저 확인
    final currentStopBuses =
        mockBusListByStop[_selectedStop.stopId] ?? [];

    matchedBuses = _findMatchingBuses(
      currentStopBuses,
      destination,
    );

    if (matchedBuses.isNotEmpty) {
      matchedStop = _selectedStop;
    }

    // 현재 정류장에서 찾지 못하면 주변 정류장 확인
    if (matchedStop == null) {
      for (final stop in mockNearbyBusStops) {
        if (stop.stopId == _selectedStop.stopId) {
          continue;
        }

        final buses =
            mockBusListByStop[stop.stopId] ?? [];

        final result = _findMatchingBuses(
          buses,
          destination,
        );

        if (result.isNotEmpty) {
          matchedStop = stop;
          matchedBuses = result;
          break;
        }
      }
    }

    final previousStopId = _selectedStop.stopId;

    setState(() {
      _isSearching = true;

      if (matchedStop != null) {
        _wasStopAutomaticallyChanged = matchedStop.stopId != previousStopId;

        _selectedStop = matchedStop;
        _displayedBusList = matchedBuses;
      } else {
        _wasStopAutomaticallyChanged = false;
        _displayedBusList = [];
      }
    });

    if (_wasStopAutomaticallyChanged) {
      _showStopChangedMessage();
    }

  }

  List<BusData> _findMatchingBuses(
    List<BusData> buses,
    String destination,
  ) {
    final normalizedDestination =
        destination.toLowerCase();

    return buses.where((bus) {
      final destinations =
          mockDestinationsByRoute[bus.routeId] ?? [];

      return destinations.any(
        (stopName) => stopName
            .toLowerCase()
            .contains(normalizedDestination),
      );
    }).map((bus) {
      final destinations =
          mockDestinationsByRoute[bus.routeId] ?? [];

      final matchedDestination =
          destinations.firstWhere(
        (stopName) => stopName
            .toLowerCase()
            .contains(normalizedDestination),
        orElse: () => destination,
      );

      return BusData(
        routeId: bus.routeId,
        busNumber: bus.busNumber,
        routeType: bus.routeType,
        startStop: bus.startStop,
        endStop: bus.endStop,
        matchedStop: '$matchedDestination (임시)',
        remainingStops: bus.remainingStops,
        arrivalMinutes: bus.arrivalMinutes,
        isFavorite: bus.isFavorite,
      );
    }).toList();
  }

  // 검색 초기화
  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _isSearching = false;

      _displayedBusList = List.from(
        mockBusListByStop[_selectedStop.stopId] ?? [],
      );
    });
  }

  // 버스 카드 선택
  Future<void> _openBusDetail(BusData bus) async {
    final updatedBus = await Navigator.push<BusData>(
      context,
      MaterialPageRoute(
        builder: (context) => BusDetailScreen(
          bus: bus,
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
      _displayedBusList = _displayedBusList.map((item) {
        if (item.routeId == updatedBus.routeId) {
          return updatedBus;
        }

        return item;
      }).toList();
    });
  }

  // 즐겨찾기 버튼 선택
  void _toggleFavorite(BusData bus) {
    setState(() {
      _displayedBusList = _displayedBusList.map((item) {
        if (item.routeId == bus.routeId) {
          return item.copyWith(
            isFavorite : !item.isFavorite,
          );
        }

        return item;
      }).toList();
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
                  '정류장 선택',
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

                for (final stop in mockNearbyBusStops)
                  ListTile(
                    leading: Icon(
                      stop.stopId == _selectedStop.stopId
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
                      '${stop.distanceM}m (임시)',
                    ),
                    onTap: () {
                      setState(() {
                        _selectedStop = stop;

                        _displayedBusList = List.from(
                          mockBusListByStop[stop.stopId] ?? [],
                        );

                        _isSearching = false;
                        _searchController.clear();
                      });

                      Navigator.pop(bottomSheetContext);
                    },
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
            "'${_searchController.text.trim()}' 목적지 검색 결과 (임시)",
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
                    _selectedStop.stopName,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedStop.distanceM}m (임시)',
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
              '목적지를 지나는 버스를 찾지 못했습니다. (임시)',
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
            bus: _displayedBusList[index],
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