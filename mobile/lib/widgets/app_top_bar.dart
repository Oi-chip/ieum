import 'package:flutter/material.dart';

class AppTopBar extends StatelessWidget {
  final VoidCallback onExitTap;
  final VoidCallback onSettingsTap;

  const AppTopBar({
    super.key,
    required this.onExitTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        8,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: OutlinedButton(
              onPressed: onExitTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
              child: const Text(
                '나가기',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

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

          SizedBox(
            width: 100,
            child: OutlinedButton(
              onPressed: onSettingsTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}
