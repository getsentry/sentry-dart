import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/integrations/connectivity_integration.dart';
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

  test(
      '$ConnectivityIntegration: connectivity changed `bluetooth` adds `wifi` breadcrumb',
      () {
    final integration = fixture.getSut();
    integration.call(fixture.hub, fixture.options);

    integration.addBreadcrumb(ConnectivityResult.bluetooth);

    final crumb = verify(
      fixture.hub.addBreadcrumb(captureAny),
    ).captured.first as Breadcrumb;

    verifyBreadcrumb(crumb, 'wifi');
  });

  test(
      '$ConnectivityIntegration: connectivity changed `wifi` adds `wifi` breadcrumb',
      () {
    final integration = fixture.getSut();
    integration.call(fixture.hub, fixture.options);

    integration.addBreadcrumb(ConnectivityResult.wifi);

    final crumb = verify(
      fixture.hub.addBreadcrumb(captureAny),
    ).captured.first as Breadcrumb;

    verifyBreadcrumb(crumb, 'wifi');
  });

  test(
      '$ConnectivityIntegration: connectivity changed `vpn` adds `vpn` breadcrumb',
      () {
    final integration = fixture.getSut();
    integration.call(fixture.hub, fixture.options);

    integration.addBreadcrumb(ConnectivityResult.vpn);

    final crumb = verify(
      fixture.hub.addBreadcrumb(captureAny),
    ).captured.first as Breadcrumb;

    verifyBreadcrumb(crumb, 'wifi');
  });

  test(
      '$ConnectivityIntegration: connectivity changed `ethernet` adds `ethernet` breadcrumb',
      () {
    final integration = fixture.getSut();
    integration.call(fixture.hub, fixture.options);

    integration.addBreadcrumb(ConnectivityResult.ethernet);

    final crumb = verify(
      fixture.hub.addBreadcrumb(captureAny),
    ).captured.first as Breadcrumb;

    verifyBreadcrumb(crumb, 'ethernet');
  });

  test(
      '$ConnectivityIntegration: connectivity changed `mobile` adds  `cellular` breadcrumb',
      () {
    final integration = fixture.getSut();
    integration.call(fixture.hub, fixture.options);

    integration.addBreadcrumb(ConnectivityResult.mobile);

    final crumb = verify(
      fixture.hub.addBreadcrumb(captureAny),
    ).captured.first as Breadcrumb;

    verifyBreadcrumb(crumb, 'cellular');
  });

  test(
      '$ConnectivityIntegration: connectivity changed `other` adds `other` breadcrumb',
      () {
    final integration = fixture.getSut();
    integration.call(fixture.hub, fixture.options);

    integration.addBreadcrumb(ConnectivityResult.other);

    final crumb = verify(
      fixture.hub.addBreadcrumb(captureAny),
    ).captured.first as Breadcrumb;

    verifyBreadcrumb(crumb, 'other');
  });

  test(
      '$ConnectivityIntegration: connectivity changed `none` adds `none` breadcrumb',
      () {
    final integration = fixture.getSut();
    integration.call(fixture.hub, fixture.options);

    integration.addBreadcrumb(ConnectivityResult.none);

    final crumb = verify(
      fixture.hub.addBreadcrumb(captureAny),
    ).captured.first as Breadcrumb;

    verifyBreadcrumb(crumb, 'none');
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions(dsn: fakeDsn);

  ConnectivityIntegration getSut() {
    return ConnectivityIntegration();
  }
}
