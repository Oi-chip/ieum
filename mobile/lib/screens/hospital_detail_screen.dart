import 'package:flutter/material.dart';

import '../models/hospital_data.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/sos_menu.dart';
import '../widgets/voice_button.dart';

class HospitalDetailScreen extends StatelessWidget {
  final HospitalData hospital;

  const HospitalDetailScreen({
    super.key,
    required this.hospital,
  });

  // 아직 구현되지 않은 기능 안내
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

  // 전화하기
  void _callHospital(BuildContext context) {
    _showTemporaryMessage(
      context,
      '${hospital.hospitalName} 전화 연결 기능은 추후 구현합니다. (임시)',
    );
  }

  // 병원 목록으로 돌아가기
  void _goBackToHospitalList(BuildContext context) {
    Navigator.pop(context);
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
                  context,
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
                    _buildHospitalSummary(),

                    const SizedBox(height: 18),

                    _buildHospitalInfo(context),

                    const SizedBox(height: 24),

                    _buildBackButton(context),
                  ],
                ),
              ),
            ),

            _buildVoiceButton(context),
          ],
        ),
      ),
    );
  }

  // 병원 이름과 진료 여부
  Widget _buildHospitalSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF81C784),
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              hospital.hospitalName,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Row(
            children: [
              Icon(
                Icons.circle,
                size: 18,
                color: hospital.isOpen
                    ? Colors.green
                    : Colors.red,
              ),
              const SizedBox(width: 6),
              Text(
                hospital.isOpen
                    ? '진료 중'
                    : '진료 종료',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 병원 상세 정보
  Widget _buildHospitalInfo(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            icon: Icons.schedule,
            title: '운영 시간',
            value: hospital.operatingTime,
          ),

          const Divider(height: 28),

          _buildPhoneSection(context),

          const Divider(height: 28),

          _buildInfoRow(
            icon: Icons.location_on_outlined,
            title: '주소',
            value: hospital.address ?? '주소 정보 없음',
          ),

          const Divider(height: 28),

          _buildInfoRow(
            icon: Icons.directions_walk,
            title: '거리',
            value:
                '${hospital.distanceKm.toStringAsFixed(1)}km (임시)',
          ),
        ],
      ),
    );
  }

  // 일반 정보 한 줄
  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 27,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }

  // 전화번호와 전화하기 버튼
    Widget _buildPhoneSection(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            const Icon(
                Icons.phone,
                size: 27,
            ),
            const SizedBox(width: 12),
            const SizedBox(
                width: 90,
                child: Text(
                '전화번호',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                ),
                ),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                hospital.phoneNumber ?? '전화번호 정보 없음',
                style: const TextStyle(
                    fontSize: 18,
                ),
                ),
            ),
            ],
        ),

        const SizedBox(height: 14),

        SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
            onPressed: hospital.phoneNumber == null
                ? null
                : () {
                    _callHospital(context);
                    },
            icon: const Icon(
                Icons.phone,
                size: 24,
            ),
            label: const Text(
                '전화하기',
                style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                ),
            ),
            ),
        ),
        ],
    );
    }

  // 병원 목록으로 돌아가는 버튼
  Widget _buildBackButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton.icon(
        onPressed: () {
          _goBackToHospitalList(context);
        },
        icon: const Icon(
          Icons.list,
          size: 26,
        ),
        label: const Text(
          '병원 목록 보기',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 공통 음성 인식 버튼
  Widget _buildVoiceButton(BuildContext context) {
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
            context,
            '음성 인식 기능은 추후 연결합니다. (임시)',
          );
        },
      ),
    );
  }
}