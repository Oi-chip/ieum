import 'package:flutter/material.dart';
import '../data/app_settings.dart';
import '../data/region_data.dart';
import 'province_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  
  @override
  State<SettingsScreen> createState() => _SettingsScreenState(); 
}

class _SettingsScreenState extends State<SettingsScreen> {
  int selectedFontSize = 1;
  String selectedRegion = '현재 위치';
  
  final TextEditingController emergencyContactController = TextEditingController();

  static const String emergencyContactKey = 'emergencyContact';
  static const String selectedRegionKey = 'selectedRegion';
  static const String selectedFontSizeKey = 'selectedFontSize';

  final SharedPreferencesAsync preferences = SharedPreferencesAsync();

  @override
  void initState() {
   super.initState();
   loadEmergencyContact();
   loadSelectedRegion();
   loadSelectedFontSize();
  }

  // 저장된 긴급 연락망 불러오기
  Future<void> loadEmergencyContact() async {
    final String contact = await preferences.getString(emergencyContactKey) ?? '';

    if (!mounted) {
      return;
    }

    emergencyContactController.text = contact;
  }

  // 저장된 지역 불러오기
  Future<void> loadSelectedRegion() async {
    final String? region = await preferences.getString(selectedRegionKey);
    if (!mounted || region == null) {
      return;
    }
    
    setState(() {
      selectedRegion = region;
    });
  }

  // 저장된 글씨 크기 불러오기
  Future<void> loadSelectedFontSize() async {
    final int? fontSize = await preferences.getInt(selectedFontSizeKey);
    if (!mounted || fontSize == null) {
      return;
    }

    if (fontSize < 0 || fontSize > 3) {
      return;
    }

    setState(() {
      selectedFontSize = fontSize;
    });
  }

  // 글씨 크기 변경하고 저장하기
  Future<void> updateFontSize(int fontSize) async {
    await preferences.setInt(
      selectedFontSizeKey,
      fontSize,
    );

    if (!mounted) {
      return;
    }

    appFontScale.value = appFontScales[fontSize];

    setState(() {
      selectedFontSize = fontSize;
    });
  }

  // 긴급 연락망 저장하기
  Future<void> saveEmergencyContact() async {
    final String contact = emergencyContactController.text.trim();

    if (contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('긴급 연락망 번호를 입력하세요.'),
        ),
      );
      return;
    }

    await preferences.setString(
      emergencyContactKey,
      contact,
    );

    if (!mounted) {
      return;
    }
      
    FocusScope.of(context).unfocus();
  }

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
          child: ListView(
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
                                  updateFontSize(
                                    selectedFontSize - 1,
                                  );
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
                                updateFontSize(
                                  selectedFontSize + 1,
                                );
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

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: emergencyContactController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                              fontSize: 22,
                            ),
                            decoration: const InputDecoration(
                              hintText: '010-0000-0000',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: saveEmergencyContact,
                            child: const Text(
                              '확인',
                              style: TextStyle(
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                    await preferences.setString(
                      selectedRegionKey,
                      region,
                    );

                    if (!mounted) {
                      return;
                    }

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