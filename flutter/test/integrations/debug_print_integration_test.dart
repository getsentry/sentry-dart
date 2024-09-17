import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/integrations/debug_print_integration.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  tearDown(() {
    debugPrint = debugPrintSynchronously;
  });

  test('$DebugPrintIntegration: debugPrint adds a breadcrumb', () {
    final integration = fixture.getSut();
    integration.call(fixture.hub, fixture.getOptions());

    debugPrint('Foo Bar');

    final breadcrumb = verify(
      fixture.hub.addBreadcrumb(captureAny),
    ).captured.first as Breadcrumb;

    expect(breadcrumb.message, 'Foo Bar');
  });

  test(
      '$DebugPrintIntegration: debugPrint does not add a breadcrumb after close',
      () {
    final integration = fixture.getSut();
    integration.call(fixture.hub, fixture.getOptions());
    integration.close();

    debugPrint('Foo Bar');

    verifyNever(fixture.hub.addBreadcrumb(captureAny));
  });

  test(
      '$DebugPrintIntegration: close changes debugPrint back to default implementation',
      () {
    final original = debugPrint;

    final integration = fixture.getSut();
    integration.call(fixture.hub, fixture.getOptions());
    integration.close();

    expect(debugPrint, original);
  });

  test('$DebugPrintIntegration: disabled in debug builds', () {
    final integration = fixture.getSut();
    integration.call(fixture.hub, fixture.getOptions(debug: true));

    debugPrint('Foo Bar');

    verifyNever(fixture.hub.addBreadcrumb(captureAny));
  });

  test('$DebugPrintIntegration: disabled if enablePrintBreadcrumbs = false',
      () {
    final integration = fixture.getSut();
    integration.call(
      fixture.hub,
      fixture.getOptions(enablePrintBreadcrumbs: false),
    );

    debugPrint('Foo Bar');

    verifyNever(fixture.hub.addBreadcrumb(captureAny));
  });

  test(
      '$DebugPrintIntegration: close works if debugPrintIntegration.call was not called',
      () {
    final integration = fixture.getSut();

    // test is successful if no exception is thrown
    expect(() => integration.close(), returnsNormally);
  });
}

class Fixture {
  final hub = MockHub();

  SentryFlutterOptions getOptions({
    bool debug = false,
    bool enablePrintBreadcrumbs = true,
  }) {
    return defaultTestOptions(MockPlatformChecker(isDebug: debug))
      ..enablePrintBreadcrumbs = enablePrintBreadcrumbs;
  }

  DebugPrintIntegration getSut() {
    return DebugPrintIntegration();
  }
}
