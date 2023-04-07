import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/widgets_binding_integration.dart';

import '../mocks.mocks.dart';

/// Tests that require `WidgetsFlutterBinding.ensureInitialized();` not
/// being called at all.
void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('widgetsBindingIntegration does not add integration', () {
    final integration = WidgetsBindingIntegration();

    integration(fixture.hub, fixture.options);

    expect(false,
        fixture.options.sdk.integrations.contains('widgetsBindingIntegration'));
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions();
}
