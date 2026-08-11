import 'package:flutter/material.dart';

class HospitalScreen extends StatelessWidget {
  const HospitalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('병원'),
      ),
      body: const Center(
        child: Text(
          '병원 화면 (임시)',
          style: TextStyle(
            fontSize: 26,
          ),
        ),
      ),
    );
  }
}