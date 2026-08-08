import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const IeumApp());
}

class IeumApp extends StatelessWidget {
  const IeumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '이음',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
