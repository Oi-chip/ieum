import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/hospital_screen.dart';
import '../services/call_service.dart';

// SOS 실행에 실패했을 때 사용자에게 원인을 안내합니다.
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

// 앱 전체에서 공통으로 사용하는 SOS 선택창
void showSosMenu(BuildContext context) {
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
                subtitle: const Text('전화 앱에서 119로 연결합니다.'),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  if (!await CallService.call('119') && context.mounted) {
                    _showTemporaryMessage(context, '전화 앱을 실행하지 못했습니다.');
                  }
                },
              ),

              const Divider(),

              // 보호자
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
                subtitle: const Text('설정에 저장한 긴급 연락망으로 전화합니다.'),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  final number = await SharedPreferencesAsync().getString('emergencyContact');
                  if (!context.mounted) return;
                  if (number == null || number.trim().isEmpty) {
                    _showTemporaryMessage(context, '설정에서 긴급 연락망을 먼저 등록해 주세요.');
                  } else if (!await CallService.call(number) && context.mounted) {
                    _showTemporaryMessage(context, '전화 앱을 실행하지 못했습니다.');
                  }
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
                subtitle: const Text('현재 위치에서 가까운 응급실을 찾습니다.'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HospitalScreen(emergencyOnly: true)),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
