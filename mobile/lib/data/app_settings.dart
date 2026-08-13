import 'package:flutter/material.dart';

// 설정 화면의 0~3단계에 대응하는 실제 글씨 배율
const List<double> appFontScales = [
  0.9,
  1.0,
  1.15,
  1.3,
];

// 앱 전체가 공유하는 현재 글씨 배율
final ValueNotifier<double> appFontScale =
    ValueNotifier<double>(appFontScales[1]);