import 'package:flutter/material.dart';

import '../mock_data/home_mock_data.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('지역 소식'), centerTitle: true),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: mockNewsList.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return Card(
              child: ListTile(
                minVerticalPadding: 18,
                leading: const Icon(Icons.campaign_outlined, size: 34),
                title: Text(
                  mockNewsList[index].title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
