import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/binding_utils.dart';
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
    _channel.setMockMethodCallHandler(null);
  });

  test('WidgetsFlutterBindingIntegration adds integration', () async {
    final integration = WidgetsFlutterBindingIntegration();
    await integration(fixture.hub, fixture.options);

    expect(
        fixture.options.sdk.integrations
            .contains('widgetsFlutterBindingIntegration'),
        true);
  });

  test('WidgetsFlutterBindingIntegration calls ensureInitialized', () async {
    var called = false;
    var ensureInitialized = () {
      called = true;
      return BindingUtils.getWidgetsBindingInstance()!;
    };
    final integration = WidgetsFlutterBindingIntegration(ensureInitialized);
    await integration(fixture.hub, fixture.options);

    expect(called, true);
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions(dsn: fakeDsn);

  LoadReleaseIntegration getIntegration({PackageLoader? loader}) {
    return LoadReleaseIntegration(loader ?? loadRelease);
  }

  Future<PackageInfo> loadRelease() {
    return Future.value(PackageInfo(
      appName: 'sentry_flutter',
      packageName: 'foo.bar',
      version: '1.2.3',
      buildNumber: '789',
      buildSignature: '',
    ));
  }
}
