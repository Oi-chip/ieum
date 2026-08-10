import 'package:flutter/material.dart';

import '../mock_data/home_mock_data.dart';

import '../widgets/home_bus_card.dart';
import '../widgets/home_hospital_card.dart';
import '../widgets/home_news_card.dart';
import '../widgets/home_weather_card.dart';
import '../widgets/voice_button.dart';

import 'bus_screen.dart';
import 'hospital_screen.dart';
//import 'news_screen.dart';
//import 'settings_screen.dart';
//import 'weather_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ==========================================
  // SOS 선택창
  // ==========================================
  void _showSosMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '긴급 도움',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  '필요한 도움을 선택해 주세요.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 24),

                // 119
                ListTile(
                  leading: const Icon(
                    Icons.local_phone,
                    color: Colors.red,
                    size: 32,
                  ),
                  title: const Text(
                    '119',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    '119 전화 연결 기능 (추후 구현)',
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    _showTemporaryMessage(
                      context,
                      '119 전화 연결 기능은 추후 구현합니다. (임시)',
                    );
                  },
                ),

                const Divider(),

                // 보호자 연락
                ListTile(
                  leading: const Icon(
                    Icons.person,
                    size: 32,
                  ),
                  title: const Text(
                    '보호자에게 연락',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    '등록된 보호자 연락 기능 (추후 구현)',
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    _showTemporaryMessage(
                      context,
                      '보호자 연락 기능은 추후 구현합니다. (임시)',
                    );
                  },
                ),

                const Divider(),

                // 가까운 응급실
                ListTile(
                  leading: const Icon(
                    Icons.local_hospital,
                    color: Colors.red,
                    size: 32,
                  ),
                  title: const Text(
                    '가까운 응급실',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    '가까운 응급실 검색 기능 (추후 구현)',
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    _showTemporaryMessage(
                      context,
                      '가까운 응급실 검색 기능은 추후 구현합니다. (임시)',
                    );
                  },
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 아직 구현되지 않은 기능 안내
  // ==========================================
  void _showTemporaryMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ==========================================
  // 화면 이동
  // ==========================================
  void _goToBusScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BusScreen(),
      ),
    );
  }

  void _goToHospitalScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HospitalScreen(),
      ),
    );
  }

  void _goToWeatherScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WeatherScreen(),
      ),
    );
  }

  void _goToNewsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewsScreen(),
      ),
    );
  }

  void _goToSettingsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // 상단 영역
            // 나가기 / 이음 / 설정
            // ==========================================
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                8,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // 나가기
                      SizedBox(
                        width: 90,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.maybePop(context);
                          },
                          child: const Text(
                            '나가기',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // 앱 이름
                      const Expanded(
                        child: Center(
                          child: Text(
                            '이음',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // 설정
                      SizedBox(
                        width: 90,
                        child: OutlinedButton(
                          onPressed: () {
                            _goToSettingsScreen(context, '설정 화면은 B팀과 연계 예정(임시)');
                          },
                          child: const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.settings,
                                size: 18,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '설정',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ==========================================
                  // 현재 위치
                  // 나중에 GPS 데이터로 교체할 부분
                  // ==========================================
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 24,
                        ),

                        const SizedBox(width: 6),

                        Expanded(
                          child: Text(
                            '현재 위치 : ${mockLocation.locationName}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(
              height: 1,
            ),

            // ==========================================
            // 메인 카드 영역
            // ==========================================
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 버스
                    HomeBusCard(
                      bus: mockBus,
                      onTap: () {
                        _goToBusScreen(context);
                      },
                    ),

                    const SizedBox(height: 14),

                    // 병원
                    HomeHospitalCard(
                      hospital: mockHospital,
                      onTap: () {
                        _goToHospitalScreen(context);
                      },
                      onSosTap: () {
                        _showSosMenu(context);
                      },
                    ),

                    const SizedBox(height: 14),

                    // 날씨
                    HomeWeatherCard(
                      weather: mockWeather,
                      onTap: () {
                        _goToWeatherScreen(context, '날씨 화면은 B팀과 연계 예정(임시)');
                      },
                    ),

                    const SizedBox(height: 14),

                    // 지역 소식
                    HomeNewsCard(
                      newsList: mockNewsList,
                      onTap: () {
                        _goToNewsScreen(context, '날씨 화면은 B팀과 연계 예정(임시)');
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ==========================================
            // 공통 음성 인식 버튼
            // ==========================================
            Container(
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
              ),
              child: VoiceButton(
                onTap: () {
                  _showTemporaryMessage(
                    context,
                    '음성 인식 기능은 추후 연결합니다. (임시)',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}