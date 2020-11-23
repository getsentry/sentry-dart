//@TestOn('ios')
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'mocks.dart';

class MockTransport extends Mock implements Transport {}

void main() {
  const MethodChannel _channel = MethodChannel('sentry_flutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  bool called = false;

  setUp(() {
    _channel.setMockMethodCallHandler((MethodCall methodCall) async {
      called = true;
      return {
        'integrations': ['NativeIntegration'],
        'package': {'sdk_name': 'native-package', 'version': '1.0'},
        'contexts': {
          'device': {'name': 'Device1'},
          'app': {'app_name': 'test-app'},
          'os': {'name': 'os1'},
          'gpu': {'name': 'gpu1'},
          'browser': {'name': 'browser1'},
          'runtime': {'name': 'RT1'},
          'theme': 'material',
        }
      };
    });
  });

  tearDown(() {
    _channel.setMockMethodCallHandler(null);
  });

  test('should apply the loadContextsIntegration eventProcessor', () async {
    final options = SentryOptions()..dsn = fakeDsn;
    final hub = Hub(options);

    loadContextsIntegration(options, _channel)(hub, options);

    expect(options.eventProcessors.length, 1);

    final e = SentryEvent();
    final event = await options.eventProcessors.first(e, null);

    expect(called, true);
    expect(event.contexts.device.name, 'Device1');
    expect(event.contexts.app.name, 'test-app');
    expect(event.contexts.operatingSystem.name, 'os1');
    expect(event.contexts.gpu.name, 'gpu1');
    expect(event.contexts.browser.name, 'browser1');
    expect(
        event.contexts.runtimes.any((element) => element.name == 'RT1'), true);
    expect(event.contexts['theme'], 'material');
    expect(
      event.sdk.packages.any((element) => element.name == 'native-package'),
      true,
    );
    expect(event.sdk.integrations.contains('NativeIntegration'), true);
  });
}
