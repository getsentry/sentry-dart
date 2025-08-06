import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

extension ReplayWidgetTesterUtil on WidgetTester {
  Future<T> pumpAndWaitUntil<T>(Future<T> future,
      {bool requiredToComplete = true}) async {
    final timeout =
        requiredToComplete ? Duration(seconds: 10) : Duration(seconds: 1);
    final startTime = DateTime.now();
    bool completed = false;
    do {
      await pumpAndSettle(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 1));
      completed = await future
          .then((v) => true)
          .timeout(const Duration(milliseconds: 10), onTimeout: () => false);
    } while (!completed && DateTime.now().difference(startTime) < timeout);

    if (requiredToComplete) {
      if (!completed) {
        throw TimeoutException(
            'Future not completed', DateTime.now().difference(startTime));
      }
      return future;
    } else {
      return Future.value(null);
    }
  }
}
