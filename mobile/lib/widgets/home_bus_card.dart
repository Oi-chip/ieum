import 'package:flutter/material.dart';

import '../models/home_data.dart';

class HomeBusCard extends StatelessWidget {
  final BusSummary bus;
  final VoidCallback onTap;

  const HomeBusCard({
    super.key,
    required this.bus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F3FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF90CAF9),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 90,
              child: Text(
                '버스',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bus.stopName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    bus.busNumber,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    bus.route,
                    style: const TextStyle(
                      fontSize: 17,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    bus.arrivalTime,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              size: 34,
            ),
          ],
        ),
      ),
    );
  }
}