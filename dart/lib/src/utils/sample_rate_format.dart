import 'dart:math';

import 'package:meta/meta.dart';

@internal
class SampleRateFormat {
  static String format(double sampleRate) {
    final rounded = dp(sampleRate, 16);
    final fixed = rounded.toStringAsFixed(16);
    return fixed.replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
  }

  static double dp(double val, int places){
    num mod = pow(10.0, places);
    return ((val * mod).round().toDouble() / mod);
  }
}
