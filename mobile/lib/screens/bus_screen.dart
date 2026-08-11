import 'package:flutter/material.dart';

class BusScreen extends StatelessWidget {
  const BusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('버스'),
      ),
      body: const Center(
        child: Text(
          '버스 화면 (임시)',
          style: TextStyle(
            fontSize: 26,
          ),
        ),
      ),
    );
  }
}