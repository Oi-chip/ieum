import 'package:flutter/material.dart';

const List<double> appFontScales = [
  0.9,
  1.0,
  1.15,
  1.3,
];

final ValueNotifier<double> appFontScale =
    ValueNotifier<double>(appFontScales[1]);
