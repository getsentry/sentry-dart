// ignore_for_file: avoid_print
// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// This needs needs to be run with:
//
// flutter drive \
//   --driver=integration_test/test_driver/driver.dart \
//   --target=integration_test/sentry_widgets_flutter_binding_test.dart --profile
//
// This test case will NOT fail in debug builds, hence why we need to test it
// in at least a profile build.

void main() {
  final originalBinding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('$SentryWidgetsFlutterBinding', () {
    testWidgets('return existing binding', (tester) async {
      final binding = SentryWidgetsFlutterBinding.ensureInitialized();

      expect(binding, equals(originalBinding));
    });
  });
}
