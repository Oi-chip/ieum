import 'package:flutter/material.dart';

import '../models/bus_data.dart';
import '../services/api_service.dart';
import '../services/favorite_bus_service.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/voice_button.dart';
import '../widgets/sos_menu.dart';
import 'settings_screen.dart';

class BusDetailScreen extends StatefulWidget {
  final BusData bus;
  final BusStopData stop;

  const BusDetailScreen({super.key, required this.bus, required this.stop});

  @override
  State<BusDetailScreen> createState() => _BusDetailScreenState();
}

class _BusDetailScreenState extends State<BusDetailScreen> {
  late BusDetailData _detail;
  late bool _isFavorite;
  bool _isLoadingRoute = true;
  String? _routeError;

  @override
  void initState() {
    super.initState();

    _detail = BusDetailData(
      nearbyStop: widget.stop,
      bus: widget.bus,
      stops: const [],
    );
    _isFavorite = widget.bus.isFavorite;

    _loadFavorite();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    if (mounted) {
      setState(() {
        _isLoadingRoute = true;
        _routeError = null;
      });
    }
    try {
      final detail = await ApiService.instance.getBusRoute(
        widget.stop,
        widget.bus,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoadingRoute = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingRoute = false;
        _routeError = error.toString();
      });
      _showTemporaryMessage(error.toString());
    }
  }

  // 휴대폰에 저장된 즐겨찾기 상태 불러오기
  Future<void> _loadFavorite() async {
    final isFavorite = await FavoriteBusService.isFavorite(widget.bus.routeId);

    if (!mounted) {
      return;
    }

    setState(() {
      _isFavorite = isFavorite;
    });
  }

  // 아직 구현되지 않은 기능 안내
  void _showTemporaryMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // 즐겨찾기 추가 또는 해제
  Future<void> _toggleFavorite() async {
    final isFavorite = await FavoriteBusService.toggleFavorite(
      widget.bus.routeId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isFavorite = isFavorite;
    });
  }

  // 버스 상세 화면 음성 명령 처리
  Future<void> _handleVoiceCommand(String text) async {
    final command = text.toLowerCase().replaceAll(' ', '');

    if (command.contains('뒤로') ||
        command.contains('목록') ||
        command.contains('나가기')) {
      _goBackToBusList();
      return;
    }

    if (command.contains('즐겨찾기')) {
      final wantsRemoval =
          command.contains('해제') ||
          command.contains('취소') ||
          command.contains('삭제');
      final wantsAddition = command.contains('추가') || command.contains('등록');

      if ((wantsRemoval && !_isFavorite) || (wantsAddition && _isFavorite)) {
        _showTemporaryMessage(
          _isFavorite ? '이미 즐겨찾기에 등록되어 있습니다.' : '이미 즐겨찾기가 해제되어 있습니다.',
        );
        return;
      }

      await _toggleFavorite();
      if (!mounted) {
        return;
      }
      _showTemporaryMessage(_isFavorite ? '즐겨찾기에 추가했습니다.' : '즐겨찾기를 해제했습니다.');
      return;
    }

    final busNumberMatch = RegExp(
      r'(\d+(?:\s*-\s*\d+)?)\s*번(?:\s*버스)?',
    ).firstMatch(text);
    if (busNumberMatch != null) {
      final number = busNumberMatch.group(1)!.replaceAll(RegExp(r'\s+'), '');
      _goBackToBusList(searchBusNumber: number);
      return;
    }

    _showTemporaryMessage(
      "'$text'(으)로 인식했습니다. 다른 버스 번호, 즐겨찾기 또는 목록으로라고 말해 주세요.",
    );
  }

  // 버스 목록 화면으로 돌아가기
  void _goBackToBusList({String? searchBusNumber}) {
    final updatedBus = widget.bus.copyWith(isFavorite: _isFavorite);

    Navigator.pop(
      context,
      BusDetailResult(bus: updatedBus, searchBusNumber: searchBusNumber),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        final updatedBus = widget.bus.copyWith(isFavorite: _isFavorite);

        Navigator.pop(context, BusDetailResult(bus: updatedBus));
      },
      child: Scaffold(
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),

              const Divider(height: 1),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNearbyStopSection(),

                      const SizedBox(height: 20),

                      _buildBusSummarySection(),

                      const SizedBox(height: 20),

                      _buildRouteTimeSection(),

                      const SizedBox(height: 20),

                      _buildRouteSection(),

                      const SizedBox(height: 24),

                      _buildBackButton(),
                    ],
                  ),
                ),
              ),

              _buildVoiceButton(),
            ],
          ),
        ),
      ),
    );
  }

  // 가까운 정류장 표시
  Widget _buildNearbyStopSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '가까운 정류장',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _detail.nearbyStop.stopName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${_detail.nearbyStop.distanceM}m',
            style: const TextStyle(fontSize: 15, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // 선택한 버스 요약정보
  Widget _buildBusSummarySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF90CAF9), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _detail.bus.busNumber,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              IconButton(
                onPressed: _toggleFavorite,
                icon: Icon(
                  _isFavorite ? Icons.star : Icons.star_border,
                  size: 38,
                ),
                tooltip: '즐겨찾기',
              ),
            ],
          ),

          if (_detail.bus.routeType != null) ...[
            const SizedBox(height: 4),
            Text(
              _detail.bus.routeType!,
              style: const TextStyle(fontSize: 17, color: Colors.black54),
            ),
          ],

          const SizedBox(height: 14),

          Text(
            _buildRouteText(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 14),

          Text(
            _buildArrivalText(),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text(
            _buildRemainingStopsText(),
            style: const TextStyle(fontSize: 17, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // 첫차, 막차, 배차간격 표시
  Widget _buildRouteTimeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '운행 정보',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 14),

          Text(
            '첫차 : ${_detail.firstBusTime ?? '정보 없음'}',
            style: const TextStyle(fontSize: 18),
          ),

          const SizedBox(height: 8),

          Text(
            '막차 : ${_detail.lastBusTime ?? '정보 없음'}',
            style: const TextStyle(fontSize: 18),
          ),

          const SizedBox(height: 8),

          Text(_buildIntervalText(), style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  // 전체 노선 표시
  Widget _buildRouteSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '노선 상세 정보',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 18),

          if (_isLoadingRoute)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_routeError != null)
            Center(
              child: Column(
                children: [
                  Text(_routeError!, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _loadRoute,
                    icon: const Icon(Icons.refresh),
                    label: const Text('노선 다시 불러오기'),
                  ),
                ],
              ),
            ),

          for (int index = 0; index < _detail.stops.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.circle, size: 15),

                    if (index != _detail.stops.length - 1)
                      Container(width: 2, height: 42, color: Colors.black26),
                  ],
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      _routeStopLabel(index),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 버스 목록으로 돌아가는 버튼
  Widget _buildBackButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton.icon(
        onPressed: _goBackToBusList,
        icon: const Icon(Icons.list, size: 26),
        label: const Text(
          '버스 목록 보기',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // 공통 음성 인식 버튼
  Widget _buildVoiceButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: const Color(0xFFF8FAFC),
      child: VoiceButton(onResult: _handleVoiceCommand),
    );
  }

  String _buildRouteText() {
    final start = _detail.bus.startStop;
    final end = _detail.bus.endStop;

    if (start != null && end != null) {
      if (start == end) {
        final via = _detail.bus.viaStop;
        return via == null ? '$start 출발·도착 순환노선' : '$start → $via → $end';
      }
      return '$start → $end';
    }

    return '노선 정보 없음';
  }

  String _routeStopLabel(int index) {
    final stopName = _detail.stops[index].stopName;
    final labels = <String>[];
    if (index == 0) labels.add('출발');
    if (stopName == _detail.bus.viaStop) labels.add('회차');
    if (index == _detail.stops.length - 1) labels.add('도착');
    return labels.isEmpty ? stopName : "$stopName (${labels.join('·')})";
  }

  String _buildArrivalText() {
    if (_detail.bus.arrivalMinutes == null) {
      return '도착 정보 없음';
    }

    return '${_detail.bus.arrivalMinutes}분 후 도착';
  }

  String _buildRemainingStopsText() {
    if (_detail.bus.remainingStops == null) {
      return '남은 정류장 정보 없음';
    }

    return '${_detail.bus.remainingStops}개 정류장 전';
  }

  String _buildIntervalText() {
    if (_detail.weekdayIntervalMinutes == null) {
      return '배차간격 : 정보 없음';
    }

    return '평일 배차간격 : '
        '${_detail.weekdayIntervalMinutes}분';
  }
}
