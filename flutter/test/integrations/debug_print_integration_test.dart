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

  test('$DebugPrintIntegration: debugPrint adds a breadcrumb', () {
    final integration = fixture.getSut();
    integration.call(fixture.hub, fixture.options);

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
    integration.call(fixture.hub, fixture.options);
    integration.close();

    debugPrint('Foo Bar');

    verifyNever(fixture.hub.addBreadcrumb(captureAny));
  });

  test(
      '$DebugPrintIntegration: close changes debugPrint back to default implementation',
      () {
    final original = debugPrint;

    final integration = fixture.getSut();
    integration.call(fixture.hub, fixture.options);
    integration.close();

    expect(debugPrint, original);
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryFlutterOptions(dsn: fakeDsn);

  DebugPrintIntegration getSut() {
    return DebugPrintIntegration();
  }
}
