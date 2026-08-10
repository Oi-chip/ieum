import 'package:flutter/material.dart';

class DistrictSelectionScreen extends StatelessWidget {
  const DistrictSelectionScreen({
    super.key,
    required this.province,
    required this.districts,
  });

  // 앞 화면에서 선택한 도
  final String province;

  // 선택한 도의 시·군·구 목록
  final List<String> districts;

  @override
  Widget build(BuildContext context) {
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

                  Expanded(
                    child: Text(
                      '$province 지역 선택',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$province 안의 지역을 선택하세요.',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.blue,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              Expanded(
                child: ListView.separated(
                  itemCount: districts.length,
                  separatorBuilder: (context, index) {
                    return const SizedBox(height: 12);
                  },
                  itemBuilder: (context, index) {
                    final String district = districts[index];

                    return OutlinedButton(
                      onPressed: () {
                        final String selectedRegion =
                            '$province $district';

                        Navigator.pop(
                          context,
                          selectedRegion,
                        );
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
                      child: Text(
                        district,
                        style: const TextStyle(
                          fontSize: 22,
                        ),
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