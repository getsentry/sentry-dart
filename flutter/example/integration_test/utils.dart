import 'dart:async';

import 'package:flutter/cupertino.dart';

/// Restores Flutter's `FlutterError.onError` to its original state after executing a function.
///
/// `testWidgets` and `SentryFlutter.init` automatically override `FlutterError.onError`.
/// If `FlutterError.onError` is not restored to its original state and an assertion fails
/// Flutter will complain and throw an error.
///
/// This function ensures `FlutterError.onError` is restored to its initial state after `fn` runs.
/// It must be called **after** the function executes but **before** any assertions.
FutureOr<void> restoreFlutterOnErrorAfter(FutureOr<void> Function() fn) async {
  final originalOnError = FlutterError.onError;
  await fn();
  final overriddenOnError = FlutterError.onError;

  FlutterError.onError = (FlutterErrorDetails details) {
    if (overriddenOnError != originalOnError) overriddenOnError?.call(details);
    originalOnError?.call(details);
  };
}
