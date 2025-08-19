import 'dart:async';
// ignore: unnecessary_import
import 'package:meta/meta.dart';

import 'package:flutter/foundation.dart';

@internal
class TimerDebouncer {
  final int milliseconds;
  Timer? _timer;

  TimerDebouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
