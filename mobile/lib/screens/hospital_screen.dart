import 'dart:async';

import 'package:flutter/material.dart';

import '../models/hospital_data.dart';
import '../models/gps_location.dart';
import '../services/api_service.dart';
import '../services/call_service.dart';
import '../services/selected_location_service.dart';
import '../services/tts_service.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/hospital_card.dart';
import '../widgets/sos_menu.dart';
import '../widgets/voice_button.dart';

import 'hospital_detail_screen.dart';
import 'settings_screen.dart';

class HospitalScreen extends StatefulWidget {
  final bool emergencyOnly;

  const HospitalScreen({super.key, this.emergencyOnly = false});

  @override
  State<HospitalScreen> createState() => _HospitalScreenState();
}

class _HospitalScreenState extends State<HospitalScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<HospitalData> _displayedHospitals = [];
  GpsLocation? _location;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 조회나 입력 오류를 화면 하단에 안내합니다.
  void _showTemporaryMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // 병원 검색
  Future<List<HospitalData>?> _loadHospitals({String? keyword}) async {
    setState(() => _isLoading = true);
    try {
      final location =
          _location ??
          await SelectedLocationService.instance.getLocation(
            requireRegion: true,
          );
      var hospitals = await ApiService.instance.getNearbyHospitals(
        location,
        keyword: keyword,
      );
      if (widget.emergencyOnly) {
        hospitals = hospitals
            .where((hospital) => hospital.hasEmergencyRoom)
            .toList();
      }
      if (!mounted) return null;
      setState(() {
        _location = location;
        _displayedHospitals = hospitals;
        _isLoading = false;
      });
      return hospitals;
    } catch (error) {
      if (!mounted) return null;
      setState(() => _isLoading = false);
      _showTemporaryMessage(error.toString());
      return null;
    }
  }

  void _searchHospital() {
    FocusScope.of(context).unfocus();

    final keyword = _searchController.text.trim();

    _loadHospitals(keyword: keyword.isEmpty ? null : keyword);
  }

  // 검색 초기화
  void _clearSearch() {
    _searchController.clear();

    _loadHospitals();
  }

  // 병원 화면 음성 명령 처리
  Future<void> _handleVoiceCommand(String text) async {
    final command = text.toLowerCase().replaceAll(' ', '');

    if (command.contains('뒤로') ||
        command.contains('홈') ||
        command.contains('나가기')) {
      Navigator.pop(context);
      return;
    }

    if ((command.contains('가까운') || command.contains('주변')) &&
        (command.contains('병원') || command.contains('의원'))) {
      _clearSearch();
      _showTemporaryMessage('가까운 병원 목록을 표시합니다.');
      return;
    }

    final keyword = text
        .replaceFirst(RegExp(r'^병원\s*검색\s*'), '')
        .replaceAll(RegExp(r'(검색해\s*줘|검색|찾아\s*줘|알려\s*줘|보여\s*줘)$'), '')
        .trim();

    if (keyword.isEmpty) {
      _showTemporaryMessage('검색할 병원 이름을 말해 주세요.');
      return;
    }

    _searchController.text = keyword;
    await _searchHospitalByName(keyword);
  }

  Future<void> _searchHospitalByName(String keyword) async {
    final hospitals = await _loadHospitals(keyword: keyword);
    if (!mounted || hospitals == null) return;

    final normalizedKeyword = keyword.toLowerCase().replaceAll(' ', '');
    final exactMatches = hospitals
        .where(
          (hospital) =>
              hospital.hospitalName.toLowerCase().replaceAll(' ', '') ==
              normalizedKeyword,
        )
        .toList();
    final directMatch = exactMatches.length == 1
        ? exactMatches.first
        : hospitals.length == 1
        ? hospitals.first
        : null;

    if (hospitals.isEmpty) {
      final guide = '$keyword 검색 결과가 없습니다.';
      _showTemporaryMessage(guide);
      unawaited(TtsService.instance.speak(guide));
      return;
    }

    if (directMatch != null) {
      unawaited(
        TtsService.instance.speak('${directMatch.hospitalName}을 찾았습니다.'),
      );
      await _openHospitalDetail(directMatch);
      return;
    }

    unawaited(TtsService.instance.speak('$keyword 검색 결과를 표시합니다.'));
  }

  // 병원 전화하기
  Future<void> _callHospital(HospitalData hospital) async {
    final phoneNumber = hospital.phoneNumber;

    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      _showTemporaryMessage('등록된 전화번호가 없습니다.');
      return;
    }

    final success = await CallService.call(phoneNumber);

    if (!mounted) {
      return;
    }

    if (!success) {
      _showTemporaryMessage('전화 앱을 실행하지 못했습니다.');
    }
  }

  // 병원 상세화면 이동
  Future<void> _openHospitalDetail(HospitalData hospital) async {
    final searchKeyword = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => HospitalDetailScreen(hospital: hospital),
      ),
    );

    if (!mounted || searchKeyword == null) return;
    _searchController.text = searchKeyword;
    await _searchHospitalByName(searchKeyword);
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
              onSettingsTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                if (mounted) {
                  _location = null;
                  await _loadHospitals();
                }
              },
            ),

            const Divider(height: 1),

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
    return Row(
      children: [
        Icon(Icons.location_on, size: 26),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '조회 지역 : ${_location?.displayName ?? '확인 중'}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
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
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close),
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
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_displayedHospitals.isEmpty) {
      return const SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
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
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    final sortedHospitals = List<HospitalData>.from(_displayedHospitals)
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return Column(
      children: [
        for (int index = 0; index < sortedHospitals.length; index++) ...[
          HospitalCard(
            hospital: sortedHospitals[index],
            onTap: () {
              _openHospitalDetail(sortedHospitals[index]);
            },
            onCallTap: () {
              _callHospital(sortedHospitals[index]);
            },
          ),

          if (index != sortedHospitals.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  // 공통 음성 인식 버튼
  Widget _buildVoiceButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: const Color(0xFFF8FAFC),
      child: VoiceButton(onResult: _handleVoiceCommand),
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
        icon: const Icon(Icons.home_outlined, size: 26),
        label: const Text(
          '홈 화면으로',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: const BorderSide(color: Color(0xFF90CAF9), width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
