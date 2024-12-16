import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/binding_wrapper.dart';

// Note: testing that SentryWidgetsFlutterBinding.ensureInitialized() returns
// the existing binding if one exists is not reliable to test in debug builds
// A previous faulty implementation was passing in debug but not in profile/release builds
// See flutter/example/integration_test/sentry_widgets_flutter_binding_test.dart

void main() {
  group('$SentryWidgetsFlutterBinding', () {
    test(
        'no existing binding: ensureInitialized() returns SentryWidgetsFlutterBinding binding',
        () {
      final binding = SentryWidgetsFlutterBinding.ensureInitialized();

      expect(binding, equals(WidgetsBinding.instance));
    });
  });
}
