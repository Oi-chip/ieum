import 'package:flutter/material.dart';

// 아직 구현되지 않은 SOS 기능의 임시 안내 메시지
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
                subtitle: const Text(
                  '119 전화 연결 기능 (추후 구현)',
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);

                  _showTemporaryMessage(
                    context,
                    '119 전화 연결 기능은 추후 구현합니다. (임시)',
                  );
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
                subtitle: const Text(
                  '등록된 보호자 연락 기능 (추후 구현)',
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);

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
                  Navigator.pop(bottomSheetContext);

                  _showTemporaryMessage(
                    context,
                    '가까운 응급실 검색 기능은 추후 구현합니다. (임시)',
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