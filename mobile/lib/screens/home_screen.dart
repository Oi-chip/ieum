import 'package:flutter/material.dart';

import '../mock_data/home_mock_data.dart';

import '../widgets/app_top_bar.dart';
import '../widgets/home_bus_card.dart';
import '../widgets/home_hospital_card.dart';
import '../widgets/home_news_card.dart';
import '../widgets/home_weather_card.dart';
import '../widgets/voice_button.dart';

import 'bus_screen.dart';
import 'hospital_screen.dart';
import 'news_screen.dart';
import 'settings_screen.dart';
import 'weather_screen.dart';

// ==========================================
// SOS 메뉴 항목 데이터
// ==========================================
class _SosOption {
  const _SosOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.message,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String message;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color _backgroundColor = Color(0xFFF8FAFC);

  // ==========================================
  // SOS 선택 항목
  // ==========================================
  static const List<_SosOption> _sosOptions = [
    _SosOption(
      icon: Icons.local_phone,
      iconColor: Colors.red,
      title: '119',
      subtitle: '119 전화 연결 기능 (추후 구현)',
      message: '119 전화 연결 기능은 추후 구현합니다. (임시)',
    ),
    _SosOption(
      icon: Icons.person,
      iconColor: Colors.black87,
      title: '보호자에게 연락',
      subtitle: '등록된 보호자 연락 기능 (추후 구현)',
      message: '보호자 연락 기능은 추후 구현합니다. (임시)',
    ),
    _SosOption(
      icon: Icons.local_hospital,
      iconColor: Colors.red,
      title: '가까운 응급실',
      subtitle: '가까운 응급실 검색 기능 (추후 구현)',
      message: '가까운 응급실 검색 기능은 추후 구현합니다. (임시)',
    ),
  ];

  // ==========================================
  // 임시 안내 메시지
  // ==========================================
  void _showTemporaryMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ==========================================
  // 버스 화면 이동
  // ==========================================
  void _goToBusScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BusScreen()),
    );
  }

  // ==========================================
  // 병원 화면 이동
  // ==========================================
  void _goToHospitalScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HospitalScreen()),
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

  void _goToNewsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewsScreen()),
    );
  }

  // ==========================================
  // SOS 선택창
  // ==========================================
  void _showSosMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '긴급 도움',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  '필요한 도움을 선택해 주세요.',
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),

                const SizedBox(height: 24),

                // SOS 항목 반복 생성
                for (int i = 0; i < _sosOptions.length; i++) ...[
                  ListTile(
                    leading: Icon(
                      _sosOptions[i].icon,
                      color: _sosOptions[i].iconColor,
                      size: 32,
                    ),
                    title: Text(
                      _sosOptions[i].title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(_sosOptions[i].subtitle),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);

                      _showTemporaryMessage(context, _sosOptions[i].message);
                    },
                  ),

                  if (i != _sosOptions.length - 1) const Divider(),
                ],

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // 현재 위치 표시
  // ==========================================
  Widget _buildLocationBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            const Icon(Icons.location_on, size: 24),

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

  // ==========================================
  // 메인 카드 목록
  // ==========================================
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
            onTap: () => _goToWeatherScreen(context),
          ),

          const SizedBox(height: 14),

          // 지역 소식 카드
          HomeNewsCard(
            newsList: mockNewsList,
            onTap: () => _goToNewsScreen(context),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 화면 구성
  // ==========================================
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
              onSosTap: () {
                _showSosMenu(context);
              },
              onSettingsTap: () {
                _goToSettingsScreen(context);
              },
            ),

            // 현재 위치
            _buildLocationBar(),

            const Divider(height: 1),

            // 메인 카드 영역
            Expanded(child: _buildCardList(context)),

            // ==========================================
            // 공통 음성 인식 버튼
            // ==========================================
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(color: _backgroundColor),
              child: VoiceButton(
                onTap: () {
                  _showTemporaryMessage(context, '음성 인식 기능은 추후 연결합니다. (임시)');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
