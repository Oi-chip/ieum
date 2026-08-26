import 'package:flutter/material.dart';

import '../models/bus_data.dart';

class BusListCard extends StatelessWidget {
  final BusData bus;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final String? boardingStopName;
  final int? boardingStopDistanceM;
  final bool showRouteIdentifier;

  const BusListCard({
    super.key,
    required this.bus,
    required this.onTap,
    this.onFavoriteTap,
    this.boardingStopName,
    this.boardingStopDistanceM,
    this.showRouteIdentifier = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      bus.isFavorite ? Icons.star : Icons.star_border,
                      size: 34,
                    ),
                    tooltip: '즐겨찾기',
                  ),
                ],
              ),

              if (bus.routeType != null) ...[
                const SizedBox(height: 2),
                Text(
                  bus.routeType!,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],

              if (bus.apiBusNumber != bus.busNumber) ...[
                const SizedBox(height: 2),
                Text(
                  '공공데이터 등록 번호 ${bus.apiBusNumber}',
                  style: const TextStyle(fontSize: 15, color: Colors.black54),
                ),
              ],

              if (showRouteIdentifier) ...[
                const SizedBox(height: 2),
                Text(
                  '세부 노선 ${_routeIdentifier()}',
                  style: const TextStyle(fontSize: 15, color: Colors.black54),
                ),
              ],

              const SizedBox(height: 14),

              Row(
                children: [
                  const Icon(Icons.route, size: 22),
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

              if (boardingStopName != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.directions_bus_filled_outlined, size: 21),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '승차 정류장 : $boardingStopName'
                        '${boardingStopDistanceM == null ? '' : ' · ${_distanceText(boardingStopDistanceM!)}'}',
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ],
                ),
              ],

              if (bus.matchedStop != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 21),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '도착 정류장 : ${bus.matchedStop}',
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ],
                ),
              ],

              if (bus.stopsBetween != null || bus.vehicleType != null) ...[
                const SizedBox(height: 10),
                Text(
                  [
                    if (bus.stopsBetween != null) '${bus.stopsBetween}개 정류장 이동',
                    if (bus.vehicleType != null) bus.vehicleType!,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],

              if (!bus.dataComplete) ...[
                const SizedBox(height: 8),
                const Text(
                  '일부 노선 정보는 제공되지 않습니다.',
                  style: TextStyle(fontSize: 15, color: Colors.deepOrange),
                ),
              ],

              const SizedBox(height: 18),

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

  String _buildRouteText() {
    final start = bus.startStop;
    final end = bus.endStop;

    if (start != null && end != null) {
      if (start == end) {
        if (bus.viaStop != null) {
          return '$start → ${bus.viaStop} → $end';
        }
        return '$start 출발·도착 순환노선';
      }
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

  String _routeIdentifier() {
    final id = bus.routeId;
    return id.length <= 3 ? id : id.substring(id.length - 3);
  }

  String _distanceText(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  String _buildRemainingStopsText() {
    if (bus.remainingStops == null) {
      return '남은 정류장 정보 없음';
    }

    return '${bus.remainingStops}개 정류장 전';
  }

  String _buildArrivalText() {
    if (bus.arrivalMinutes == null) {
      return '도착 정보 없음';
    }

    return '${bus.arrivalMinutes}분 후 도착';
  }
}
