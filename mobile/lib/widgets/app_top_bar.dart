import 'package:flutter/material.dart';

class AppTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onSosTap;
  final VoidCallback onSettingsTap;
  final VoidCallback? onBackTap;

  const AppTopBar({
    super.key,
    required this.title,
    required this.onSosTap,
    required this.onSettingsTap,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    final actionWidth = onBackTap == null ? 100.0 : 80.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          if (onBackTap != null) ...[
            BackButton(onPressed: onBackTap),
            const SizedBox(width: 4),
          ],
          SizedBox(
            width: actionWidth,
            child: ElevatedButton(
              onPressed: onSosTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'SOS',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(
            width: actionWidth,
            child: OutlinedButton(
              onPressed: onSettingsTap,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.settings, size: 18),
                  SizedBox(width: 4),
                  Text(
                    '설정',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          if (onBackTap != null) const SizedBox(width: 52),
        ],
      ),
    );
  }
}
