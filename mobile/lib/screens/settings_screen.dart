import 'package:flutter/material.dart';
import '../data/region_data.dart';
import 'province_selection_screen.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  
  @override
  State<SettingsScreen> createState() => _SettingsScreenState(); 
}

class _SettingsScreenState extends State<SettingsScreen> {
  int selectedFontSize = 1;
  String selectedRegion = '현재 위치';
  
  final TextEditingController emergencyContactController = TextEditingController();
  
  @override
  void dispose() {
    emergencyContactController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // 나가기 버튼
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.maybePop(context);
                  },
                  child: const Text('나가기'),
                ),
              ),

              const SizedBox(height: 20),

              // 글씨 크기 박스
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: Column(
                  children: [
                    const Text(
                      '글씨 크기',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 글씨 크기 줄이기 버튼
                        IconButton(
                          onPressed: selectedFontSize > 0
                              ? () {
                                  setState(() {
                                    selectedFontSize--;
                                  });
                              }
                            : null,
                            
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 32,
                          ),
                        ),

                        // 1단계
                        Text(
                           '가',
                          style: TextStyle(
                            fontSize: 18,
                            color: selectedFontSize == 0
                                ? Colors.green
                                : Colors.black,
                            fontWeight: selectedFontSize == 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                            
                          ),
                        ),

                        // 2단계
                        Text(
                          '가',
                          style: TextStyle(
                            fontSize: 24,
                            color: selectedFontSize == 1
                                ? Colors.green
                                : Colors.black,
                            fontWeight: selectedFontSize == 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),

                        // 3단계
                        Text(
                          '가',
                          style: TextStyle(
                            fontSize: 30,
                            color: selectedFontSize == 2
                                ? Colors.green
                                : Colors.black,
                            fontWeight: selectedFontSize == 2
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),

                        // 4단계
                        Text(
                          '가',
                          style: TextStyle(
                            fontSize: 36,
                             color: selectedFontSize == 3
                                ? Colors.green
                                : Colors.black,
                            fontWeight: selectedFontSize == 3
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),

                        // 글씨 크기 키우기 버튼
                        IconButton(
                          onPressed: selectedFontSize < 3
                              ? () {
                                  setState(() {
                                    selectedFontSize++;
                                  });
                              }
                            : null,
                          
                          icon: const Icon(
                            Icons.add_circle_outline,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ],   
                ),
              ),

              const SizedBox(height: 20),

              // 긴급연락망 박스
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey), 
                ),
                child: Column(
                  children: [
                    const Text(
                      '긴급 연락망',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: emergencyContactController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        fontSize: 22,
                      ),
                      decoration: const InputDecoration(
                        hintText: '긴급 연락망 전화번호를 입력하세요.',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              
              // 지역 설정 박스
              InkWell(
                onTap: () async {
                  final String? region = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                       builder: (context) {
                        return const ProvinceSelectionScreen(
                          districtsByProvince: districtsByProvince,
                        );
                       },
                    ),
                  );

                   if (region != null && mounted) {
                    setState(() {
                      selectedRegion = region;
                    });
                   }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 48,
                      ),

                      const SizedBox(width: 20),

                      Expanded(
                        child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '지역 설정',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Text(
                              selectedRegion,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        )
                      )
                    ]
                  )

                )
              )
            ],
          ),
        ),
      ),
    );
  }
}