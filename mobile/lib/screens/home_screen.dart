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

// SOS 메뉴 항목 하나를 표현하는 데이터 클래스
class _SosOption {
  const _SosOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _backgroundColor = Color(0xFFF8FAFC);

  // 추후 구현 예정인 SOS 옵션들 (임시 안내 메시지 포함)
  static const List<_SosOption> _sosOptions = [
    _SosOption(
      icon: Icons.local_phone,
      iconColor: Colors.red,
      title: '119',
      message: '119 전화 연결 기능은 추후 구현합니다. (임시)',
    ),
    _SosOption(
      icon: Icons.person,
      iconColor: Colors.black87,
      title: '보호자에게 연락',
      message: '보호자 연락 기능은 추후 구현합니다. (임시)',
    ),
    _SosOption(
      icon: Icons.local_hospital,
      iconColor: Colors.red,
      title: '가까운 응급실',
      message: '가까운 응급실 검색 기능은 추후 구현합니다. (임시)',
    ),
  ];

  // ==========================================
  // 아직 구현되지 않은 기능 안내
  // ==========================================
  void _showTemporaryMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _goToBusScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BusScreen()),
    );
  }

  void _goToHospitalScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HospitalScreen()),
    );
  }

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
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '필요한 도움을 선택해 주세요.',
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
                const SizedBox(height: 24),

                // 옵션 리스트를 반복문으로 생성 (기존 3개 ListTile 중복 제거)
                for (final option in _sosOptions) ...[
                  ListTile(
                    leading: Icon(option.icon, color: option.iconColor, size: 32),
                    title: Text(
                      option.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('${option.title} 기능 (추후 구현)'),
                    onTap: () {
                      Navigator.pop(context);
                      _showTemporaryMessage(context, option.message);
                    },
                  ),
                  if (option != _sosOptions.last) const Divider(),
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
  Widget _buildLocationBar(BuildContext context) {
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
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 메인 카드 영역
  // ==========================================
  Widget _buildCardList(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          HomeBusCard(
            bus: mockBus,
            onTap: () => _goToBusScreen(context),
          ),
          const SizedBox(height: 14),
          HomeHospitalCard(
            hospital: mockHospital,
            onTap: () => _goToHospitalScreen(context),
            onSosTap: () => _showSosMenu(context),
          ),
          const SizedBox(height: 14),
          HomeWeatherCard(
            weather: mockWeather,
            onTap: () => _showTemporaryMessage(
              context,
              '날씨 화면은 B팀과 연계 예정입니다. (임시)',
            ),
          ),
          const SizedBox(height: 14),
          HomeNewsCard(
            newsList: mockNewsList,
            onTap: () => _showTemporaryMessage(
              context,
              '지역 소식 화면은 B팀과 연계 예정입니다. (임시)',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              onExitTap: () => _showTemporaryMessage(
                context,
                '나가기 기능은 추후 구현합니다. (임시)',
              ),
              onSettingsTap: () => _showTemporaryMessage(
                context,
                '설정 화면은 B팀과 연계 예정입니다. (임시)',
              ),
            ),
            _buildLocationBar(context),
            const Divider(height: 1),
            Expanded(child: _buildCardList(context)),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(color: _backgroundColor),
              child: VoiceButton(
                onTap: () => _showTemporaryMessage(
                  context,
                  '음성 인식 기능은 추후 연결합니다. (임시)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}