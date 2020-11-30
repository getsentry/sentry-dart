import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';

void main() {
  group('WidgetsBindingObserver', () {
    setUp(() {});

    testWidgets('memory pressure breadcrumb', (WidgetTester tester) async {
      final options = SentryFlutterOptions(options: SentryOptions());
      expect(options, isNotNull);
    });
  });
}
