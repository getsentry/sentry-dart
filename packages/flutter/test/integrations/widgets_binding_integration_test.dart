import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/integrations/widgets_binding_integration.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('WidgetsBindingIntegration', () {
    test('adds integration', () {
      final integration = WidgetsBindingIntegration();
      integration(fixture.hub, fixture.options);

      expect(
        fixture.options.sdk.integrations.contains('widgetsBindingIntegration'),
        true,
      );
    });

    test('does not add integration if multi-view app', () {
      final integration = WidgetsBindingIntegration();
      fixture.options.isMultiViewApp = true;
      integration(fixture.hub, fixture.options);

      expect(
        fixture.options.sdk.integrations.contains('widgetsBindingIntegration'),
        false,
      );
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions();
}
