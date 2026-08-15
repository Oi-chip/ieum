import 'package:flutter/material.dart';

import '../models/bus_data.dart';

class BusListCard extends StatelessWidget {
  final BusData bus;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;

  const BusListCard({
    super.key,
    required this.bus,
    required this.onTap,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 버스 번호와 즐겨찾기 버튼
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      bus.busNumber,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onFavoriteTap,
                    icon: Icon(
                      bus.isFavorite
                          ? Icons.star
                          : Icons.star_border,
                      size: 34,
                    ),
                    tooltip: '즐겨찾기',
                  ),
                ],
              ),

              // 버스 종류
              if (bus.routeType != null) ...[
                const SizedBox(height: 2),
                Text(
                  bus.routeType!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // 버스 노선 간략 정보
              Row(
                children: [
                  const Icon(
                    Icons.route,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _buildRouteText(),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // 검색 결과일 경우 실제 일치한 정류장 표시
              if (bus.matchedStop != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 21,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '검색된 목적지 : ${bus.matchedStop}',
                        style: const TextStyle(
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              // 남은 정류장 수와 도착 예상 시간
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _buildRemainingStopsText(),
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Text(
                    _buildArrivalText(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 출발지와 종점을 이용해 간략 노선 표시
  String _buildRouteText() {
    final start = bus.startStop;
    final end = bus.endStop;

    if (start != null && end != null) {
      return '$start → $end';
    }

    if (end != null) {
      return '→ $end';
    }

    if (start != null) {
      return start;
    }

    return '노선 정보 없음';
  }

  // 남은 정류장 수 표시
  String _buildRemainingStopsText() {
    if (bus.remainingStops == null) {
      return '남은 정류장 정보 없음';
    }

    return '${bus.remainingStops}개 정류장 전 (임시)';
  }

  // 도착 예상 시간 표시
  String _buildArrivalText() {
    if (bus.arrivalMinutes == null) {
      return '도착 정보 없음';
    }

    return '${bus.arrivalMinutes}분 후 도착 (임시)';
  }
}