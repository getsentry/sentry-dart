extension DateTimeExtension on DateTime {
  double get secondsSinceEpoch => microsecondsSinceEpoch / 1000000.0;
}
