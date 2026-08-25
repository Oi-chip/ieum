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

  const BusDetailScreen({
    super.key,
    required this.bus,
    required this.stop,
  });

  @override
  State<BusDetailScreen> createState() => _BusDetailScreenState();
}

class _BusDetailScreenState extends State<BusDetailScreen> {
  BusDetailData? _detail;

  late bool _isFavorite;

  bool _isLoadingRoute = true;
  bool _favoriteUpdateInProgress = false;
  bool _popInProgress = false;

  Future<void>? _favoriteUpdateFuture;

  String? _routeError;

  @override
  void initState() {
    super.initState();

    _detail = BusDetailData(
      nearbyStop: widget.stop,
      bus: widget.bus,
      firstBusTime: widget.bus.firstBusTime,
      lastBusTime: widget.bus.lastBusTime,
      weekdayIntervalMinutes: widget.bus.weekdayIntervalMinutes,
      saturdayIntervalMinutes: widget.bus.saturdayIntervalMinutes,
      sundayIntervalMinutes: widget.bus.sundayIntervalMinutes,
      stops: const [],
    );

    _isFavorite = widget.bus.isFavorite;

    _loadFavorite();
    _loadRoute();
  }

  // 버스 노선 정보 불러오기
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

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = detail;
        _isLoadingRoute = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingRoute = false;
        _routeError = error.toString();
      });

      _showTemporaryMessage(error.toString());
    }
  }

  // 휴대폰에 저장된 즐겨찾기 상태 불러오기
  Future<void> _loadFavorite() async {
    final isFavorite = await FavoriteBusService.isFavorite(
      widget.bus.routeId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isFavorite = isFavorite;
    });
  }

  // 간단한 안내 메시지 표시
  void _showTemporaryMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // 즐겨찾기 추가 또는 해제
  Future<void> _toggleFavorite() {
    final activeUpdate = _favoriteUpdateFuture;

    if (activeUpdate != null) {
      return activeUpdate;
    }

    if (_popInProgress) {
      return Future<void>.value();
    }

    final update = _performFavoriteUpdate();

    _favoriteUpdateFuture = update;

    return update;
  }

  // 실제 즐겨찾기 변경 처리
  Future<void> _performFavoriteUpdate() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _favoriteUpdateInProgress = true;
    });

    try {
      final isFavorite = await FavoriteBusService.toggleFavorite(
        widget.bus.routeKey,
        legacyRouteId: widget.bus.routeId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isFavorite = isFavorite;
      });
    } catch (error) {
      if (mounted) {
        _showTemporaryMessage(error.toString());
      }
    } finally {
      _favoriteUpdateFuture = null;

      if (mounted) {
        setState(() {
          _favoriteUpdateInProgress = false;
        });
      }
    }
  }

  // 버스 상세 화면 음성 명령 처리
  Future<void> _handleVoiceCommand(String text) async {
    final command = text.toLowerCase().replaceAll(' ', '');

    // 뒤로가기 또는 목록으로 이동
    if (command.contains('뒤로') ||
        command.contains('목록') ||
        command.contains('나가기')) {
      await _goBackToBusList();
      return;
    }

    // 즐겨찾기 명령
    if (command.contains('즐겨찾기')) {
      final wantsRemoval =
          command.contains('해제') ||
          command.contains('취소') ||
          command.contains('삭제');

      final wantsAddition =
          command.contains('추가') ||
          command.contains('등록');

      if (wantsRemoval && !_isFavorite) {
        _showTemporaryMessage(
          '이미 즐겨찾기가 해제되어 있습니다.',
        );
        return;
      }

      if (wantsAddition && _isFavorite) {
        _showTemporaryMessage(
          '이미 즐겨찾기에 등록되어 있습니다.',
        );
        return;
      }

      await _toggleFavorite();

      if (!mounted) {
        return;
      }

      _showTemporaryMessage(
        _isFavorite
            ? '즐겨찾기에 추가했습니다.'
            : '즐겨찾기를 해제했습니다.',
      );

      return;
    }

    // 다른 버스 번호 검색
    final busNumberMatch = RegExp(
      r'(\d+(?:\s*-\s*\d+)?)\s*번(?:\s*버스)?',
    ).firstMatch(text);

    if (busNumberMatch != null) {
      final number = busNumberMatch
          .group(1)!
          .replaceAll(RegExp(r'\s+'), '');

      await _goBackToBusList(
        searchBusNumber: number,
      );

      return;
    }

    _showTemporaryMessage(
      "'$text'(으)로 인식했습니다. "
      '다른 버스 번호, 즐겨찾기 또는 목록으로라고 말해 주세요.',
    );
  }

  // 버스 목록 화면으로 돌아가기
  Future<void> _goBackToBusList({
    String? searchBusNumber,
  }) async {
    if (_popInProgress) {
      return;
    }

    if (mounted) {
      setState(() {
        _popInProgress = true;
      });
    }

    // 즐겨찾기 저장 중이면 완료될 때까지 기다림
    final favoriteUpdate = _favoriteUpdateFuture;

    if (favoriteUpdate != null) {
      await favoriteUpdate;
    }

    if (!mounted) {
      return;
    }

    final updatedBus = widget.bus.copyWith(
      isFavorite: _isFavorite,
    );

    Navigator.pop(
      context,
      BusDetailResult(
        bus: updatedBus,
        searchBusNumber: searchBusNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        await _goBackToBusList();
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
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),

              const Divider(height: 1),

              Expanded(
                child: _buildContent(),
              ),

              _buildVoiceButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final detail = _detail;

    if (detail == null) {
      return const Center(
        child: Text(
          '버스 상세정보가 없습니다.',
          style: TextStyle(
            fontSize: 18,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNearbyStopSection(detail),

          const SizedBox(height: 20),

          _buildBusSummarySection(detail),

          const SizedBox(height: 20),

          _buildRouteTimeSection(detail),

          const SizedBox(height: 20),

          _buildRouteSection(detail),

          const SizedBox(height: 24),

          _buildBackButton(),
        ],
      ),
    );
  }

  // 승차 정류장 표시
  Widget _buildNearbyStopSection(
    BusDetailData detail,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '승차 정류장',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            detail.nearbyStop.stopName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '${detail.nearbyStop.distanceM}m',
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // 선택한 버스 요약정보
  Widget _buildBusSummarySection(
    BusDetailData detail,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF90CAF9),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detail.bus.busNumber,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              IconButton(
                onPressed: _favoriteUpdateInProgress || _popInProgress
                    ? null
                    : () {
                        _toggleFavorite();
                      },
                icon: Icon(
                  _isFavorite
                      ? Icons.star
                      : Icons.star_border,
                  size: 38,
                ),
                tooltip: '즐겨찾기',
              ),
            ],
          ),

          if (detail.bus.routeType != null) ...[
            const SizedBox(height: 4),

            Text(
              detail.bus.routeType!,
              style: const TextStyle(
                fontSize: 17,
                color: Colors.black54,
              ),
            ),
          ],

          if (detail.bus.apiBusNumber != detail.bus.busNumber) ...[
            const SizedBox(height: 4),

            Text(
              '공공데이터 등록 번호 ${detail.bus.apiBusNumber}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ],

          const SizedBox(height: 14),

          Text(
            _buildRouteText(detail),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            _buildArrivalText(detail),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            _buildRemainingStopsText(detail),
            style: const TextStyle(
              fontSize: 17,
              color: Colors.black54,
            ),
          ),

          if (detail.bus.matchedStop != null) ...[
            const SizedBox(height: 8),

            Text(
              '하차 정류장 : ${detail.bus.matchedStop}',
              style: const TextStyle(
                fontSize: 17,
              ),
            ),
          ],

          if (!detail.bus.dataComplete) ...[
            const SizedBox(height: 8),

            const Text(
              '일부 운행 정보는 제공되지 않습니다.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.deepOrange,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 첫차, 막차, 배차간격 표시
  Widget _buildRouteTimeSection(
    BusDetailData detail,
  ) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '운행 정보',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            '첫차 : ${detail.firstBusTime ?? '정보 없음'}',
            style: const TextStyle(
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '막차 : ${detail.lastBusTime ?? '정보 없음'}',
            style: const TextStyle(
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _buildIntervalText(detail),
            style: const TextStyle(
              fontSize: 18,
            ),
          ),

          if (detail.saturdayIntervalMinutes != null) ...[
            const SizedBox(height: 8),

            Text(
              '토요일 배차간격 : '
              '${detail.saturdayIntervalMinutes}분',
              style: const TextStyle(
                fontSize: 18,
              ),
            ),
          ],

          if (detail.sundayIntervalMinutes != null) ...[
            const SizedBox(height: 8),

            Text(
              '일요일 배차간격 : '
              '${detail.sundayIntervalMinutes}분',
              style: const TextStyle(
                fontSize: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 전체 노선 표시
  Widget _buildRouteSection(
    BusDetailData detail,
  ) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '노선 상세 정보',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
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
                  Text(
                    _routeError!,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton.icon(
                    onPressed: _loadRoute,
                    icon: const Icon(
                      Icons.refresh,
                    ),
                    label: const Text(
                      '노선 다시 불러오기',
                    ),
                  ),
                ],
              ),
            )
          else if (detail.stops.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '경유 정류장 정보가 제공되지 않습니다.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            for (
              int index = 0;
              index < detail.stops.length;
              index++
            ) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 15,
                      ),

                      if (index != detail.stops.length - 1)
                        Container(
                          width: 2,
                          height: 42,
                          color: Colors.black26,
                        ),
                    ],
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: 20,
                      ),
                      child: Text(
                        _routeStopLabel(
                          detail,
                          index,
                        ),
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
        onPressed: _popInProgress
            ? null
            : () {
                _goBackToBusList();
              },
        icon: const Icon(
          Icons.list,
          size: 26,
        ),
        label: const Text(
          '버스 목록 보기',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 공통 음성 인식 버튼
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
        onResult: _handleVoiceCommand,
      ),
    );
  }

  // 출발지 → 도착지 문자열 생성
  String _buildRouteText(
    BusDetailData detail,
  ) {
    final start = detail.bus.startStop;
    final end = detail.bus.endStop;

    if (start != null && end != null) {
      if (start == end) {
        final via = detail.bus.viaStop;

        if (via == null) {
          return '$start 출발·도착 순환노선';
        }

        return '$start → $via → $end';
      }

      return '$start → $end';
    }

    return '노선 정보 없음';
  }

  // 노선 정류장 이름과 승차/하차/기점/종점 정보 생성
  String _routeStopLabel(
    BusDetailData detail,
    int index,
  ) {
    final stop = detail.stops[index];
    final stopName = stop.stopName;

    final labels = <String>[];

    if (stop.order == detail.bus.boardingOrder) {
      labels.add('승차');
    } else if (index == 0) {
      labels.add('기점');
    }

    if (stopName == detail.bus.viaStop) {
      labels.add('회차');
    }

    if (stop.order == detail.bus.destinationOrder) {
      labels.add('하차');
    } else if (index == detail.stops.length - 1) {
      labels.add('종점');
    }

    if (labels.isEmpty) {
      return stopName;
    }

    return "$stopName (${labels.join('·')})";
  }

  // 도착 예정 시간 표시
  String _buildArrivalText(
    BusDetailData detail,
  ) {
    if (detail.bus.arrivalMinutes == null) {
      return '도착 정보 없음';
    }

    return '${detail.bus.arrivalMinutes}분 후 도착';
  }

  // 남은 정류장 수 표시
  String _buildRemainingStopsText(
    BusDetailData detail,
  ) {
    if (detail.bus.remainingStops == null) {
      return '남은 정류장 정보 없음';
    }

    return '${detail.bus.remainingStops}개 정류장 전';
  }

  // 평일 배차간격 표시
  String _buildIntervalText(
    BusDetailData detail,
  ) {
    if (detail.weekdayIntervalMinutes == null) {
      return '평일 배차간격 : 정보 없음';
    }

    return '평일 배차간격 : '
        '${detail.weekdayIntervalMinutes}분';
  }
}