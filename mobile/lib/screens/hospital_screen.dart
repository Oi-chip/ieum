import 'package:flutter/material.dart';

import '../mock_data/hospital_mock_data.dart';
import '../models/hospital_data.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/hospital_card.dart';
import '../widgets/sos_menu.dart';
import '../widgets/voice_button.dart';

import 'hospital_detail_screen.dart';

class HospitalScreen extends StatefulWidget {
  const HospitalScreen({super.key});

  @override
  State<HospitalScreen> createState() => _HospitalScreenState();
}

class _HospitalScreenState extends State<HospitalScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<HospitalData> _displayedHospitals = List.from(mockHospitalList);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 아직 구현되지 않은 기능 안내
  void _showTemporaryMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // 병원 검색
  void _searchHospital() {
    FocusScope.of(context).unfocus();

    final keyword = _searchController.text.trim();

    setState(() {
      _displayedHospitals = searchMockHospitals(keyword);
    });
  }

  // 검색 초기화
  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _displayedHospitals = List.from(mockHospitalList);
    });
  }

  // 전화하기
  void _callHospital(HospitalData hospital) {
    _showTemporaryMessage(
      '${hospital.hospitalName} 전화 연결 기능은 추후 구현합니다. (임시)',
    );
  }

  // 병원 상세화면 이동
  void _openHospitalDetail(HospitalData hospital) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HospitalDetailScreen(
          hospital: hospital,
        ),
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
            AppTopBar(
              title: '병원',
              onSosTap: () {
                showSosMenu(context);
              },
              onSettingsTap: () {
                _showTemporaryMessage(
                  '설정 화면은 B팀과 연계 예정입니다. (임시)',
                );
              },
            ),

            const Divider(
              height: 1,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLocationSection(),

                    const SizedBox(height: 18),

                    _buildSearchSection(),

                    const SizedBox(height: 22),

                    _buildHospitalList(),

                    const SizedBox(height: 24),

                    _buildHomeButton(),
                  ],
                ),
              ),
            ),

            _buildVoiceButton(),
          ],
        ),
      ),
    );
  }

  // 현재 위치 표시
  Widget _buildLocationSection() {
    return const Row(
      children: [
        Icon(
          Icons.location_on,
          size: 26,
        ),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            '현재 위치 : 봉화읍 (임시)',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // 병원 검색 영역
  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '병원 검색',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  _searchHospital();
                },
                decoration: InputDecoration(
                  hintText: '병원 이름을 입력해 주세요.',
                  prefixIcon: const Icon(
                    Icons.search,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(
                            Icons.close,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),
            ),

            const SizedBox(width: 8),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _searchHospital,
                child: const Text(
                  '검색',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 병원 목록
  Widget _buildHospitalList() {
    if (_displayedHospitals.isEmpty) {
      return const SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: 40,
            horizontal: 20,
          ),
          child: Column(
            children: [
              Icon(
                Icons.local_hospital_outlined,
                size: 48,
                color: Colors.black38,
              ),
              SizedBox(height: 12),
              Text(
                '검색 결과가 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sortedHospitals = List<HospitalData>.from(
      _displayedHospitals,
    )..sort(
        (a, b) => a.distanceKm.compareTo(
          b.distanceKm,
        ),
      );

    return Column(
      children: [
        for (int index = 0;
            index < sortedHospitals.length;
            index++) ...[
          HospitalCard(
            hospital: sortedHospitals[index],
            onTap: () {
              _openHospitalDetail(
                sortedHospitals[index],
              );
            },
            onCallTap: () {
              _callHospital(
                sortedHospitals[index],
              );
            },
          ),

          if (index != sortedHospitals.length - 1)
            const SizedBox(height: 14),
        ],
      ],
    );
  }

  // 공통 음성 인식 버튼
  Widget _buildVoiceButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16,
      ),
      color: const Color(0xFFF8FAFC),
      child: VoiceButton(
        onTap: () {
          _showTemporaryMessage(
            '음성 인식 기능은 추후 연결합니다. (임시)',
          );
        },
      ),
    );
  }

  // 홈 화면으로 돌아가는 버튼
  Widget _buildHomeButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: const Icon(
          Icons.home_outlined,
          size: 26,
        ),
        label: const Text(
          '홈 화면으로',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: const BorderSide(
            color: Color(0xFF90CAF9),
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

}