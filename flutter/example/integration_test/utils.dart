import 'package:flutter/cupertino.dart';

/// Restores the onError to it's original state.
/// This makes assertion errors readable.
///
/// testWidgets override Flutter.onError by default
/// If a fail happens during integration tests this would complain that
/// the FlutterError.onError was overwritten and wasn't reset to its
/// state before asserting.
///
/// This function needs to be executed before assertions.
Future<void> restoreFlutterOnErrorAfter(Future<void> Function() fn) async {
  final originalOnError = FlutterError.onError!;
  await fn();
  final overriddenOnError = FlutterError.onError!;

  FlutterError.onError = (FlutterErrorDetails details) {
    if (overriddenOnError != originalOnError) overriddenOnError(details);
    originalOnError(details);
  };
}
