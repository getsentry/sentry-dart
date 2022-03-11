import 'dart:async';

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
      final throwable = StateError('error').toString();
      final stackTrace = StackTrace.current.toString();
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

  test('Run zoned guarded completes when callback returns normally', () async {
    var completed = false;
    final completer = Completer();
    Future<void> callback() async {
      await completer.future;
    }

    final integration = RunZonedGuardedIntegration(callback);

    final integrationResult = Future.sync(() async {
      await integration(fixture.hub, fixture.options);
      completed = true;
    });

    expect(completed, false);

    completer.complete();
    await integrationResult;

    expect(completed, true);
  }, onPlatform: {'browser': Skip()});

  test('Run zoned guarded completes when callback throws', () async {
    var completed = false;
    final completer = Completer();
    Future<void> callback() async {
      await completer.future;
      throw Exception('error');
    }

    final integration = RunZonedGuardedIntegration(callback);

    final integrationResult = Future.sync(() async {
      await integration(fixture.hub, fixture.options);
      completed = true;
    });

    expect(completed, false);

    completer.complete();
    await integrationResult;

    expect(completed, true);
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
    final integration = fixture.getSut();

    await integration(fixture.hub, fixture.options);

    expect(fixture.hub.addBreadcrumbCalls.length, 1);
    final breadcrumb = fixture.hub.addBreadcrumbCalls.first.crumb;
    expect(breadcrumb.level, SentryLevel.debug);
    expect(breadcrumb.category, 'console');
    expect(breadcrumb.type, 'debug');
  });

  test(
      'Run zoned guarded does not log calls to print as breadcrumb if disabled',
      () async {
    fixture.options.enablePrintBreadcrumbs = false;

    final integration = fixture.getSut();

    await integration(fixture.hub, fixture.options);

    expect(fixture.hub.addBreadcrumbCalls.length, 0);
  });

  test('Run zoned guarded: No addBreadcrumb calls for disabled Hub', () async {
    await fixture.hub.close();

    final integration = fixture.getSut();

    await integration(fixture.hub, fixture.options);

    expect(fixture.hub.addBreadcrumbCalls.length, 0);
  });

  test('Run zoned guarded: No recursion for print() calls', () async {
    final options = SentryOptions(dsn: fakeDsn);
    final hub = PrintRecursionMockHub();

    final integration = fixture.getSut();

    await integration(hub, options);

    expect(hub.addBreadcrumbCalls.length, 1);
    final breadcrumb = hub.addBreadcrumbCalls.first.crumb;
    expect(breadcrumb.message, 'foo bar');
    expect(breadcrumb.level, SentryLevel.debug);
    expect(breadcrumb.category, 'console');
    expect(breadcrumb.type, 'debug');
  });
}

class Fixture {
  final hub = MockHub();
  final options = SentryOptions(dsn: fakeDsn);

  RunZonedGuardedIntegration getSut() {
    Future<void> callback() async {
      print('foo bar');
    }

    return RunZonedGuardedIntegration(callback);
  }
}

class PrintRecursionMockHub extends MockHub {
  @override
  bool get isEnabled => true;

  @override
  void addBreadcrumb(Breadcrumb crumb, {dynamic hint}) {
    print('recursion');
    super.addBreadcrumb(crumb, hint: hint);
  }

  @override
  ISentrySpan startTransactionWithContext(
    SentryTransactionContext transactionContext, {
    Map<String, dynamic>? customSamplingContext,
    DateTime? startTimestamp,
    bool? bindToScope,
    bool? waitForChildren,
    Duration? autoFinishAfter,
    bool? trimEnd,
  }) {
    return NoOpSentrySpan();
  }
}
