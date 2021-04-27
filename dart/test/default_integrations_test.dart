import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import 'mocks.dart';
import 'mocks/mock_hub.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test(
    'Isolate error adds integration',
    () async {
      final integration = IsolateErrorIntegration();
      await integration(
        fixture.hub,
        fixture.options,
      );

      expect(
        true,
        fixture.options.sdk.integrations.contains('isolateErrorIntegration'),
      );
    },
    onPlatform: {
      'browser': Skip(),
    },
  );

  test(
    'Isolate error capture errors',
    () async {
      final throwable = StateError('error');
      final stackTrace = StackTrace.current;
      final error = [throwable, stackTrace];

      // we could not find a way to trigger an error to the current Isolate
      // and unit test its error handling, so instead we exposed the method,
      // that handles and captures it.
      await handleIsolateError(fixture.hub, fixture.options, error);

      expect(fixture.hub.captureEventCalls.length, 1);
      final event = fixture.hub.captureEventCalls.first.event;

      expect(SentryLevel.fatal, event.level);

      final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
      expect('isolateError', throwableMechanism.mechanism.type);
      expect(true, throwableMechanism.mechanism.handled);
      expect(throwable, throwableMechanism.throwable);
    },
    onPlatform: {
      'browser': Skip(),
    },
  );

  test(
    'Run zoned guarded adds integrations',
    () async {
      Future<void> callback() async {}
      final integration = RunZonedGuardedIntegration(callback);

      await integration(fixture.hub, fixture.options);

      expect(
          true,
          fixture.options.sdk.integrations
              .contains('runZonedGuardedIntegration'));
    },
    onPlatform: {
      'browser': Skip(),
    },
  );

  test('Run zoned guarded calls callback', () async {
    var called = false;
    Future<void> callback() async {
      called = true;
    }

    final integration = RunZonedGuardedIntegration(callback);

    await integration(fixture.hub, fixture.options);

    expect(true, called);
  }, onPlatform: {'browser': Skip()});

  test('Run zoned guarded calls catches integrations errors', () async {
    final throwable = StateError('error');
    Future<void> callback() async {
      throw throwable;
    }

    final integration = RunZonedGuardedIntegration(callback);

    await integration(fixture.hub, fixture.options);

    expect(fixture.hub.captureEventCalls.length, 1);
    final event = fixture.hub.captureEventCalls.first.event;

    expect(SentryLevel.fatal, event.level);

    final throwableMechanism = event.throwableMechanism as ThrowableMechanism;
    expect('runZonedGuarded', throwableMechanism.mechanism.type);
    expect(true, throwableMechanism.mechanism.handled);
    expect(throwable, throwableMechanism.throwable);
  });

  test('Run zoned guarded logs calls to print as breadcrumb', () async {
    Future<void> callback() async {
      print('foo bar');
    }

    final integration = RunZonedGuardedIntegration(callback);

    await integration(fixture.hub, fixture.options);

    expect(fixture.hub.addBreadcrumbCalls.length, 1);
    final breadcrumb = fixture.hub.addBreadcrumbCalls.first.crumb;
    expect(breadcrumb.message, 'foo bar');
  });

  test(
      'Run zoned guarded does not log calls to print as breadcrumb if disabled',
      () async {
    fixture.options.enablePrintBreadcrumbs = false;
    Future<void> callback() async {
      print('foo bar');
    }

    final integration = RunZonedGuardedIntegration(callback);

    await integration(fixture.hub, fixture.options);

    expect(fixture.hub.addBreadcrumbCalls.length, 0);
  });

  test('Run zoned guarded: No addBreadcrumb calls for disabled Hub', () async {
    await fixture.hub.close();

    Future<void> callback() async {
      print('foo bar');
    }

    final integration = RunZonedGuardedIntegration(callback);

    await integration(fixture.hub, fixture.options);

    expect(fixture.hub.addBreadcrumbCalls.length, 0);
  });

  test('Run zoned guarded: No recursion for print() calls', () async {
    final options = SentryOptions(dsn: fakeDsn);
    final hub = PrintRecursionMockHub();

    Future<void> callback() async {
      print('foo bar');
    }

    final integration = RunZonedGuardedIntegration(callback);

    await integration(hub, options);

    expect(hub.addBreadcrumbCalls.length, 1);
    final breadcrumb = hub.addBreadcrumbCalls.first.crumb;
    expect(breadcrumb.message, 'foo bar');
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryOptions(dsn: fakeDsn);
}

class PrintRecursionMockHub extends MockHub {
  @override
  bool get isEnabled => true;

  @override
  void addBreadcrumb(Breadcrumb crumb, {dynamic hint}) {
    print('recursion');
    super.addBreadcrumb(crumb, hint: hint);
  }
}
