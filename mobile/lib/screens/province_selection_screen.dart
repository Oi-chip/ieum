import 'package:flutter/material.dart';
import 'district_selection_screen.dart';

class ProvinceSelectionScreen extends StatelessWidget {
  const ProvinceSelectionScreen({
    super.key,
    required this.districtsByProvince,
  });

  // 도별 시·군·구 목록
  final Map<String, List<String>> districtsByProvince;

  @override
  Widget build(BuildContext context) {
    final List<String> provinces =
        districtsByProvince.keys.toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('나가기'),
                  ),

                  const SizedBox(width: 20),

                  const Text(
                    '도 선택',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '도를 선택하세요.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.blue,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              Expanded(
                child: ListView.separated(
                  itemCount: provinces.length,
                  separatorBuilder: (context, index) {
                    return const SizedBox(height: 12);
                  },
                  itemBuilder: (context, index) {
                    final String province = provinces[index];

                    return OutlinedButton(
                      onPressed: () async {
                        final String? selectedRegion =
                            await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              return DistrictSelectionScreen(
                                province: province,
                                districts:
                                    districtsByProvince[province]!,
                              );
                            },
                          ),
                        );

                        if (selectedRegion != null &&
                            context.mounted) {
                          Navigator.pop(
                            context,
                            selectedRegion,
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          65,
                        ),
                        alignment: Alignment.centerLeft,
                        foregroundColor: Colors.black,
                        side: const BorderSide(
                          color: Colors.grey,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              province,
                              style: const TextStyle(
                                fontSize: 22,
                              ),
                            ),
                          ),

                          const Icon(
                            Icons.chevron_right,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}