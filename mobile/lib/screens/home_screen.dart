import 'package:flutter/material.dart';

import '../mock_data/home_mock_data.dart';

import '../widgets/app_top_bar.dart';
import '../widgets/home_bus_card.dart';
import '../widgets/home_hospital_card.dart';
import '../widgets/home_news_card.dart';
import '../widgets/home_weather_card.dart';
import '../widgets/sos_menu.dart';
import '../widgets/voice_button.dart';

import 'bus_screen.dart';
import 'hospital_screen.dart';
import 'settings_screen.dart';
import 'weather_screen.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color _backgroundColor = Color(0xFFF8FAFC);

  // 임시 안내 메시지
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

  // 버스 화면 이동
  void _goToBusScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BusScreen(),
      ),
    );
  }

  // 병원 화면 이동
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
      MaterialPageRoute(builder: (context) => const WeatherScreen()),
    );
  }

  void _goToSettingsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }


  // 현재 위치 표시
  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        6,
        16,
        10,
      ),
      child: Align(
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
    );
  }

  // 메인 카드 목록
  Widget _buildCardList(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 버스 카드
          HomeBusCard(
            bus: mockBus,
            onTap: () {
              _goToBusScreen(context);
            },
          ),

          const SizedBox(height: 14),

          // 병원 카드
          // SOS 버튼은 카드 내부에서 제거됨
          HomeHospitalCard(
            hospital: mockHospital,
            onTap: () {
              _goToHospitalScreen(context);
            },
          ),

          const SizedBox(height: 14),

          // 날씨 카드
          HomeWeatherCard(
            weather: mockWeather,
            onTap: () {
              _showTemporaryMessage(
                context,
                '날씨 화면은 B팀과 연계 예정입니다. (임시)',
              );
            },
          ),

          const SizedBox(height: 14),

          // 지역 소식 카드
          HomeNewsCard(
            newsList: mockNewsList,
            onTap: () {
              _showTemporaryMessage(
                context,
                '지역 소식 화면은 B팀과 연계 예정입니다. (임시)',
              );
            },
          ),
        ],
      ),
    );
  }

  // 화면 구성
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,

      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // 공통 상단 바
            // SOS / 이음 / 설정
            // ==========================================
            AppTopBar(
              title : '이음',
              onSosTap: () {
                showSosMenu(context);
              },
              onSettingsTap: () {
                _showTemporaryMessage(
                  context,
                  '설정 화면은 B팀과 연계 예정입니다. (임시)',
                );
              },
            ),

            // 현재 위치
            _buildLocationBar(),

            const Divider(
              height: 1,
            ),

            // 메인 카드 영역
            Expanded(
              child: _buildCardList(context),
            ),

            // 공통 음성 인식 버튼
            Container(
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16,
              ),
              decoration: const BoxDecoration(
                color: _backgroundColor,
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
