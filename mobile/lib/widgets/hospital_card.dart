import 'package:flutter/material.dart';

import '../models/hospital_data.dart';

class HospitalCard extends StatelessWidget {
  final HospitalData hospital;
  final VoidCallback onTap;
  final VoidCallback onCallTap;

  const HospitalCard({
    super.key,
    required this.hospital,
    required this.onTap,
    required this.onCallTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.black12,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 병원 이름
                  Text(
                    hospital.hospitalName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 거리
                  Text(
                    '${hospital.distanceKm.toStringAsFixed(1)}km (임시)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 진료 여부
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 20,
                      color: hospital.isOpen
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hospital.isOpen
                          ? '진료 중'
                          : '진료 종료',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 운영 시간
                Text(
                  hospital.operatingTime,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                // 전화하기
                TextButton.icon(
                  onPressed: onCallTap,
                  icon: const Icon(
                    Icons.phone,
                    size: 24,
                  ),
                  label: const Text(
                    '전화하기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}