import 'package:meta/meta.dart';

@internal
class SampleRateFormat {
  static String format(double sampleRate) {
    final fixed = sampleRate.toStringAsFixed(16);
    return fixed.replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "");
  }
}
