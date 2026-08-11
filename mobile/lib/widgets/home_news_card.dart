import 'package:flutter/material.dart';

import '../models/home_data.dart';

class HomeNewsCard extends StatelessWidget {
  final List<NewsSummary> newsList;
  final VoidCallback onTap;

  const HomeNewsCard({
    super.key,
    required this.newsList,
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
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFBDBDBD),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    '지역 소식',
                    style: TextStyle(
                      fontSize: 33,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Icon(
                  Icons.chevron_right,
                  size: 34,
                ),
              ],
            ),

            const SizedBox(height: 14),

            for (int i = 0; i < newsList.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      '•',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      newsList[i].title,
                      style: const TextStyle(
                        fontSize: 21,
                      ),
                    ),
                  ),
                ],
              ),

              if (i != newsList.length - 1)
                const Divider(
                  height: 24,
                ),
            ],
          ],
        ),
      ),
    );
  }
}