import 'dart:async';

import 'package:flutter/widgets.dart';

/// Restores Flutter's `FlutterError.onError` to its original state after executing a function.
///
/// `testWidgets` and `SentryFlutter.init` automatically override `FlutterError.onError`.
/// If `FlutterError.onError` is not restored to its original state and an assertion fails
/// Flutter will complain and throw an error.
///
/// This function ensures `FlutterError.onError` is restored to its initial state after `fn` runs.
/// Assertions must only be executed after onError has been restored.
FutureOr<void> restoreFlutterOnErrorAfter(FutureOr<void> Function() fn) async {
  final originalOnError = FlutterError.onError;
  await fn();
  final overriddenOnError = FlutterError.onError;

  FlutterError.onError = (FlutterErrorDetails details) {
    if (overriddenOnError != originalOnError) overriddenOnError?.call(details);
    originalOnError?.call(details);
  };
}

const fakeDsn = 'https://abc@def.ingest.sentry.io/1234567';

// Used to test for correct serialization of custom object in attributes / data.
class CustomObject {}
