import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/integrations/connectivity/connectivity_integration.dart';
import 'package:sentry_flutter/src/sentry_flutter_options.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  verifyBreadcrumb(Breadcrumb crumb, String connectivityData) {
    expect(crumb.category, 'device.connectivity');
    expect(crumb.type, 'connectivity');
    expect(crumb.level, SentryLevel.info);
    expect(crumb.data?['connectivity'], connectivityData);
  }

  test('adds integration', () {
    final sut = fixture.getSut();
    sut(fixture.hub, fixture.options);

    expect(fixture.options.sdk.integrations.contains('connectivityIntegration'),
        true);
  });

  test('$ConnectivityIntegration: addsBreadcrumb', () {
    final integration = fixture.getSut();
    integration.call(fixture.hub, fixture.options);

    integration.addBreadcrumb('wifi');

    final crumb = verify(
      fixture.hub.addBreadcrumb(captureAny),
    ).captured.first as Breadcrumb;

    verifyBreadcrumb(crumb, 'wifi');
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions(dsn: fakeDsn);

  ConnectivityIntegration getSut() {
    return ConnectivityIntegration();
  }
}
