@TestOn('vm')

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/load_contexts_integration.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  group(LoadContextsIntegration, () {
    const _channel = MethodChannel('sentry_flutter');

    TestWidgetsFlutterBinding.ensureInitialized();

    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    tearDown(() {
      _channel.setMockMethodCallHandler(null);
    });

    test('loadContextsIntegration adds integration', () async {
      _channel.setMockMethodCallHandler((MethodCall methodCall) async {});

      final integration = LoadContextsIntegration(_channel);

      await integration(fixture.hub, fixture.options);

      expect(
          fixture.options.sdk.integrations.contains('loadContextsIntegration'),
          true);
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions(dsn: fakeDsn);
}
