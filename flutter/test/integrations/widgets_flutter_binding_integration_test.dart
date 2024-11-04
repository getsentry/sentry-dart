import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/integrations/widgets_flutter_binding_integration.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  const _channel = MethodChannel('sentry_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  tearDown(() {
    // ignore: deprecated_member_use
    _channel.setMockMethodCallHandler(null);
  });

  test('WidgetsFlutterBindingIntegration adds integration', () {
    final integration = WidgetsFlutterBindingIntegration();
    integration(fixture.hub, fixture.options);

    expect(
        fixture.options.sdk.integrations
            .contains('widgetsFlutterBindingIntegration'),
        true);
  });

  test('WidgetsFlutterBindingIntegration calls ensureInitialized', () {
    final integration = WidgetsFlutterBindingIntegration();
    integration(fixture.hub, fixture.options);

    expect(fixture.testBindingUtils.ensureBindingInitializedCalled, true);
  });
}

class Fixture {
  final hub = MockHub();

  final options = defaultTestOptions()..bindingUtils = TestBindingWrapper();

  TestBindingWrapper get testBindingUtils =>
      options.bindingUtils as TestBindingWrapper;
}
