@TestOn('vm')
library;

// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
// ignore: implementation_imports
import 'package:sentry/src/sentry_tracer.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/iterable_utils.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/app_start/app_start_info.dart';
import 'package:sentry_flutter/src/app_start/static_standalone_app_start_emitter.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('$StaticStandaloneAppStartEmitter', () {
    test('captures detached App Start transaction', () async {
      await fixture.sut.emit(fixture.appStartInfo);

      final transaction = fixture.capturedTransactionByName('App Start')!;
      expect(
          transaction.contexts.trace?.operation, SentrySpanOperations.appStart);
      expect(
          transaction.contexts.trace?.origin, SentryTraceOrigins.autoAppStart);
      expect(transaction.timestamp, fixture.appStartInfo.end.toUtc());
      expect(transaction.measurements['app_start_cold']?.value, 50);
      expect(transaction.tracer.data['app.vitals.start.value'], 50.0);
    });

    test('does not trim standalone root to out-of-range native span', () async {
      final appStartInfo = AppStartInfo(
        AppStartType.cold,
        start: DateTime.fromMillisecondsSinceEpoch(0),
        end: DateTime.fromMillisecondsSinceEpoch(50),
        pluginRegistration: DateTime.fromMillisecondsSinceEpoch(10),
        sentrySetupStart: DateTime.fromMillisecondsSinceEpoch(15),
        nativeSpanTimes: [
          TimeSpan(
            start: DateTime.fromMillisecondsSinceEpoch(1),
            end: DateTime.fromMillisecondsSinceEpoch(100),
            description: 'out-of-range native span',
          ),
        ],
      );

      await fixture.sut.emit(appStartInfo);

      final transaction = fixture.capturedTransactionByName('App Start')!;
      expect(transaction.timestamp,
          DateTime.fromMillisecondsSinceEpoch(50).toUtc());
      expect(fixture.lastTrimEnd, isFalse);
    });

    test('attaches breakdown spans directly under App Start root', () async {
      await fixture.sut.emit(fixture.appStartInfo);

      final transaction = fixture.capturedTransactionByName('App Start')!;
      expect(
        transaction.spans.map((span) => span.context.description),
        isNot(contains('Cold Start')),
      );
      final rootSpanId = transaction.contexts.trace?.spanId;
      for (final span in transaction.spans) {
        expect(span.context.parentSpanId, rootSpanId);
        expect(span.origin, SentryTraceOrigins.autoAppStart);
      }
      expect(
        transaction.spans
            .firstWhereOrNull((span) =>
                span.context.description ==
                AppStartInfo.pluginRegistrationDescription)
            ?.context
            .operation,
        SentrySpanOperations.appStartPluginRegistration,
      );
    });
  });
}

class Fixture {
  final options = defaultTestOptions()..tracesSampleRate = 1.0;
  final hub = MockHub();
  final scope = MockScope();
  final capturedTransactions = <SentryTransaction>[];
  bool? lastTrimEnd;

  late final sut = StaticStandaloneAppStartEmitter(hub: hub);

  final appStartInfo = AppStartInfo(
    AppStartType.cold,
    start: DateTime.fromMillisecondsSinceEpoch(0),
    end: DateTime.fromMillisecondsSinceEpoch(50),
    pluginRegistration: DateTime.fromMillisecondsSinceEpoch(10),
    sentrySetupStart: DateTime.fromMillisecondsSinceEpoch(15),
    nativeSpanTimes: [
      TimeSpan(
        start: DateTime.fromMillisecondsSinceEpoch(1),
        end: DateTime.fromMillisecondsSinceEpoch(2),
        description: 'native span',
      ),
    ],
  );

  Fixture() {
    when(hub.options).thenReturn(options);
    when(hub.configureScope(captureAny)).thenAnswer((invocation) {
      final callback = invocation.positionalArguments[0] as ScopeCallback;
      callback(scope);
      return null;
    });
    when(hub.startTransactionWithContext(
      any,
      customSamplingContext: anyNamed('customSamplingContext'),
      startTimestamp: anyNamed('startTimestamp'),
      bindToScope: anyNamed('bindToScope'),
      waitForChildren: anyNamed('waitForChildren'),
      autoFinishAfter: anyNamed('autoFinishAfter'),
      trimEnd: anyNamed('trimEnd'),
      onFinish: anyNamed('onFinish'),
    )).thenAnswer((invocation) {
      final context =
          invocation.positionalArguments[0] as SentryTransactionContext;
      final startTimestamp =
          invocation.namedArguments[#startTimestamp] as DateTime?;
      final waitForChildren =
          invocation.namedArguments[#waitForChildren] as bool? ?? false;
      final autoFinishAfter =
          invocation.namedArguments[#autoFinishAfter] as Duration?;
      lastTrimEnd = invocation.namedArguments[#trimEnd] as bool? ?? false;
      final onFinish =
          invocation.namedArguments[#onFinish] as OnTransactionFinish?;

      return SentryTracer(
        context,
        hub,
        startTimestamp: startTimestamp,
        waitForChildren: waitForChildren,
        autoFinishAfter: autoFinishAfter,
        trimEnd: lastTrimEnd ?? false,
        onFinish: onFinish,
      );
    });
    when(hub.captureTransaction(
      any,
      traceContext: anyNamed('traceContext'),
    )).thenAnswer((invocation) async {
      capturedTransactions
          .add(invocation.positionalArguments[0] as SentryTransaction);
      return SentryId.empty();
    });
  }

  SentryTransaction? capturedTransactionByName(String name) {
    return capturedTransactions.firstWhereOrNull(
      (transaction) => transaction.transaction == name,
    );
  }
}

class MockScope extends Mock implements Scope {
  ISentrySpan? _span;

  @override
  ISentrySpan? get span => _span;

  @override
  set span(ISentrySpan? value) {
    _span = value;
  }
}
