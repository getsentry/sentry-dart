// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/src/sentry_tracer.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/native/native_frames.dart';
import 'package:sentry_flutter/src/navigation/time_to_display_tracker.dart';
import 'package:sentry_flutter/src/navigation/time_to_full_display_tracker.dart';
import 'package:sentry_flutter/src/navigation/time_to_initial_display_tracker.dart';

import 'fake_frame_callback_handler.dart';
import 'mocks.dart';
import 'mocks.mocks.dart';

void main() {
  late Fixture fixture;

  PageRoute<dynamic> route(RouteSettings? settings) => PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => Container(),
        settings: settings,
      );

  void _whenAnyStart(MockHub mockHub, ISentrySpan thenReturnSpan) {
    when(mockHub.startTransactionWithContext(
      any,
      bindToScope: anyNamed('bindToScope'),
      waitForChildren: anyNamed('waitForChildren'),
      autoFinishAfter: anyNamed('autoFinishAfter'),
      trimEnd: anyNamed('trimEnd'),
      onFinish: anyNamed('onFinish'),
      customSamplingContext: anyNamed('customSamplingContext'),
      startTimestamp: anyNamed('startTimestamp'),
    )).thenReturn(thenReturnSpan);
    when(mockHub.getSpan()).thenReturn(thenReturnSpan);
  }

  setUp(() {
    fixture = Fixture();
  });

  group('NativeFrames', () {
    late MockSentryNativeBinding mockBinding;

    setUp(() {
      mockBinding = MockSentryNativeBinding();
      when(mockBinding.beginNativeFrames()).thenReturn(null);
      SentryFlutter.native = mockBinding;
    });

    tearDown(() {
      SentryFlutter.native = null;
    });

    test('transaction start begins frames collection', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));
      final mockHub = _MockHub();

      final tracer = getMockSentryTracer();
      _whenAnyStart(mockHub, tracer);
      when(tracer.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      when(tracer.finished).thenReturn(false);
      when(tracer.status).thenReturn(SpanStatus.ok());

      final sut = fixture.getSut(hub: mockHub);

      sut.didPush(currentRoute, null);
      await sut.completedDisplayTracking?.future;

      // Handle internal async method calls.
      await Future.delayed(const Duration(milliseconds: 10), () {});
      verify(mockBinding.beginNativeFrames()).called(1);
    }, testOn: 'vm');

    test('transaction finish adds native frames to tracer', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final options = defaultTestOptions();
      options.tracesSampleRate = 1;
      // Drop events, otherwise sentry tries to send them to the test DSN.
      options.addEventProcessor(FunctionEventProcessor((_, __) => null));
      final hub = Hub(options);

      when(mockBinding.endNativeFrames(any))
          .thenAnswer((_) async => NativeFrames(3, 2, 1));

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);
      await sut.completedDisplayTracking?.future;

      // Get ref to created transaction
      SentryTracer? actualTransaction;
      hub.configureScope((scope) {
        actualTransaction = scope.span as SentryTracer;
      });

      // Wait for the transaction to finish the async native frame fetching
      await Future<void>.delayed(Duration(milliseconds: 1500));

      verify(mockBinding.beginNativeFrames()).called(1);

      final measurements = actualTransaction?.measurements ?? {};

      expect(measurements.length, 4);

      final expectedTotal = SentryMeasurement.totalFrames(3);
      final expectedSlow = SentryMeasurement.slowFrames(2);
      final expectedFrozen = SentryMeasurement.frozenFrames(1);

      for (final item in measurements.entries) {
        final measurement = item.value;
        if (measurement.name == expectedTotal.name) {
          expect(measurement.value, expectedTotal.value);
        } else if (measurement.name == expectedSlow.name) {
          expect(measurement.value, expectedSlow.value);
        } else if (measurement.name == expectedFrozen.name) {
          expect(measurement.value, expectedFrozen.value);
        }
      }
    }, testOn: 'vm');
  });

  group('$SentryNavigatorObserver', () {
    tearDown(() {
      fixture.timeToInitialDisplayTracker.clearForTest();
      fixture.timeToFullDisplayTracker.clear();
    });

    test('didPush starts transaction', () async {
      const name = 'Current Route';
      final currentRoute = route(RouteSettings(name: name));

      const op = 'ui.load';
      final hub = _MockHub();
      final span = getMockSentryTracer(name: name);
      when(span.context).thenReturn(SentrySpanContext(operation: op));
      _whenAnyStart(hub, span);
      when(span.finished).thenReturn(false);
      when(span.status).thenReturn(SpanStatus.ok());
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());

      final sut = fixture.getSut(
        hub: hub,
        autoFinishAfter: Duration(seconds: 5),
      );

      sut.didPush(currentRoute, null);
      await sut.completedDisplayTracking?.future;

      final context = verify(hub.startTransactionWithContext(
        captureAny,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: true,
        autoFinishAfter: anyNamed('autoFinishAfter'),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      )).captured.single as SentryTransactionContext;

      expect(context.name, name);

      hub.configureScope((scope) {
        expect(scope.span?.context.operation, op);
        expect(scope.span, span);
      });
    });

    test('do not bind transaction to scope if no op', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();

      final span = NoOpSentrySpan();
      _whenAnyStart(hub, span);
      when(hub.getSpan()).thenReturn(null);

      final sut = fixture.getSut(
        hub: hub,
        autoFinishAfter: Duration(seconds: 5),
      );

      sut.didPush(currentRoute, null);
      await sut.completedDisplayTracking?.future;

      verify(hub.startTransactionWithContext(
        any,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: true,
        autoFinishAfter: Duration(seconds: 5),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      hub.configureScope((scope) {
        expect(scope.span, null);
        expect(scope.transaction, null);
      });
    });

    test('route with empty name does not start transaction', () async {
      final currentRoute = route(null);

      final hub = _MockHub();
      final span = getMockSentryTracer();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.finished).thenReturn(false);
      when(span.status).thenReturn(SpanStatus.ok());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      verifyNever(hub.startTransactionWithContext(
        any,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: true,
        autoFinishAfter: anyNamed('autoFinishAfter'),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      hub.configureScope((scope) {
        expect(scope.span, null);
      });
    });

    test('no transaction on opt-out', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final span = getMockSentryTracer();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      _whenAnyStart(hub, span);
      when(span.finished).thenReturn(false);
      when(span.status).thenReturn(SpanStatus.ok());

      final sut = fixture.getSut(hub: hub, enableAutoTransactions: false);

      sut.didPush(currentRoute, null);

      verifyNever(hub.startTransactionWithContext(
        any,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: true,
        autoFinishAfter: anyNamed('autoFinishAfter'),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      hub.configureScope((scope) {
        expect(scope.span, null);
      });
    });

    test('do not bind to scope if already set', () {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      hub.scope.span = NoOpSentrySpan();

      final span = getMockSentryTracer();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.finished).thenReturn(false);
      when(span.status).thenReturn(SpanStatus.ok());
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);

      verify(hub.startTransactionWithContext(
        any,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: true,
        autoFinishAfter: anyNamed('autoFinishAfter'),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      hub.configureScope((scope) {
        expect(scope.span, NoOpSentrySpan());
      });
    });

    test('didPush finishes previous transaction', () async {
      final firstRoute = route(RouteSettings(name: 'First Route'));
      final secondRoute = route(RouteSettings(name: 'Second Route'));

      final hub = _MockHub();
      final span = getMockSentryTracer(finished: false) as SentryTracer;
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.status).thenReturn(null);
      when(span.finished).thenReturn(false);
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      when(span.children).thenReturn([]);
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(firstRoute, null);
      sut.didPush(secondRoute, firstRoute);
      sut.didPop(secondRoute, null);

      hub.configureScope((scope) {
        expect(scope.span, null);
      });

      verify(span.finish(endTimestamp: captureAnyNamed('endTimestamp')))
          .called(2);
    });

    test('didPop finishes transaction', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final span = getMockSentryTracer(finished: false) as SentryTracer;
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.status).thenReturn(null);
      when(span.finished).thenReturn(false);
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);
      when(span.children).thenReturn([]);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);
      sut.didPop(currentRoute, null);

      hub.configureScope((scope) {
        expect(scope.span, null);
      });

      verify(span.finish(endTimestamp: captureAnyNamed('endTimestamp')))
          .called(1);
    });

    test('multiple didPop only finish transaction once', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final span = getMockSentryTracer(finished: false) as SentryTracer;
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.status).thenReturn(null);
      when(span.children).thenReturn([]);
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);
      await sut.completedDisplayTracking?.future;

      sut.didPop(currentRoute, null);
      sut.didPop(currentRoute, null);

      hub.configureScope((scope) {
        expect(scope.span, null);
      });

      verify(span.finish(endTimestamp: captureAnyNamed('endTimestamp')))
          .called(1);
    });

    // e.g when a user navigates to another screen before ttfd or ttid is finished
    test('cancelled TTID and TTFD spans do not add measurements', () async {
      final initialRoute = route(RouteSettings(name: 'Initial Route'));
      final newRoute = route(RouteSettings(name: 'New Route'));

      final hub = _MockHub();
      final transaction = getMockSentryTracer(finished: false) as SentryTracer;

      final mockChildTTID = MockSentrySpan();
      final mockChildTTFD = MockSentrySpan();

      when(transaction.children).thenReturn([
        mockChildTTID,
        mockChildTTFD,
      ]);

      when(transaction.measurements).thenReturn(<String, SentryMeasurement>{});

      when(mockChildTTID.finished).thenReturn(false);
      when(mockChildTTID.context).thenReturn(SentrySpanContext(
          operation: SentrySpanOperations.uiTimeToInitialDisplay));
      when(mockChildTTID.status).thenReturn(SpanStatus.cancelled());

      when(mockChildTTFD.finished).thenReturn(false);
      when(mockChildTTFD.context).thenReturn(SentrySpanContext(
          operation: SentrySpanOperations.uiTimeToFullDisplay));
      when(mockChildTTFD.status).thenReturn(SpanStatus.cancelled());

      when(transaction.context)
          .thenReturn(SentrySpanContext(operation: 'navigation'));
      when(transaction.status).thenReturn(null);
      when(transaction.finished).thenReturn(false);

      when(transaction.startChild(
        'ui.load.initial_display',
        description: anyNamed('description'),
        startTimestamp: anyNamed('startTimestamp'),
      )).thenReturn(MockSentrySpan());

      when(hub.getSpan()).thenReturn(transaction);
      when(hub.startTransactionWithContext(
        any,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: true,
        autoFinishAfter: anyNamed('autoFinishAfter'),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      )).thenReturn(transaction);

      final sut =
          fixture.getSut(hub: hub, autoFinishAfter: Duration(seconds: 5));

      // Simulate pushing the initial route
      sut.didPush(initialRoute, null);

      // Simulate navigating to a new route before TTID and TTFD spans finish
      sut.didPush(newRoute, initialRoute);

      // Allow async operations to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify that the TTID and TTFD spans are finished with a cancelled status
      verify(mockChildTTID.finish(
              endTimestamp: anyNamed('endTimestamp'),
              status: SpanStatus.deadlineExceeded()))
          .called(1);
      verify(mockChildTTFD.finish(
              endTimestamp: anyNamed('endTimestamp'),
              status: SpanStatus.deadlineExceeded()))
          .called(1);

      // Verify that the measurements are not added to the transaction
      final measurements = transaction.measurements;
      expect(measurements.containsKey('time_to_initial_display'), isFalse);
      expect(measurements.containsKey('time_to_full_display'), isFalse);
    });

    test('unfinished ttfd will match ttid duration if available', () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final options = hub.options as SentryFlutterOptions;
      options.enableTimeToFullDisplayTracing = true;

      final transaction = getMockSentryTracer(finished: false) as SentryTracer;
      final ttidSpan = MockSentrySpan();
      final ttfdSpan = MockSentrySpan();
      when(transaction.children).thenReturn([
        ttfdSpan,
        ttidSpan,
      ]);
      when(ttidSpan.finished).thenReturn(false);
      when(ttfdSpan.finished).thenReturn(false);
      when(ttidSpan.context).thenReturn(SentrySpanContext(
          operation: SentrySpanOperations.uiTimeToInitialDisplay));
      when(ttfdSpan.context).thenReturn(SentrySpanContext(
          operation: SentrySpanOperations.uiTimeToFullDisplay));
      when(transaction.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(transaction.status).thenReturn(null);
      when(transaction.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      when(transaction.startChild('ui.load.full_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, transaction);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);

      final anotherRoute = route(RouteSettings(name: 'Another Route'));
      sut.didPush(anotherRoute, null);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final ttidFinishVerification = verify(ttidSpan.finish(
        endTimestamp: captureAnyNamed('endTimestamp'),
        status: anyNamed('status'),
      ));
      final ttidEndTimestamp =
          ttidFinishVerification.captured.single as DateTime;

      final ttfdFinishVerification = verify(ttfdSpan.finish(
        endTimestamp: captureAnyNamed('endTimestamp'),
        status: anyNamed('status'),
      ));
      final ttfdEndTimestamp =
          ttfdFinishVerification.captured.single as DateTime;

      expect(ttfdEndTimestamp.toUtc(), equals(ttidEndTimestamp.toUtc()));
    }, skip: 'Flaky, see https://github.com/getsentry/sentry-dart/issues/2428');

    test(
        'unfinished children will be finished with deadline_exceeded on didPush',
        () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final options = hub.options as SentryFlutterOptions;
      options.enableTimeToFullDisplayTracing = true;

      final transaction = getMockSentryTracer(finished: false) as SentryTracer;
      final ttidSpan = MockSentrySpan();
      final ttfdSpan = MockSentrySpan();
      when(transaction.children).thenReturn([
        ttfdSpan,
        ttidSpan,
      ]);
      when(ttidSpan.finished).thenReturn(false);
      when(ttfdSpan.finished).thenReturn(false);
      when(ttidSpan.context).thenReturn(SentrySpanContext(
          operation: SentrySpanOperations.uiTimeToInitialDisplay));
      when(ttfdSpan.context).thenReturn(SentrySpanContext(
          operation: SentrySpanOperations.uiTimeToFullDisplay));
      when(transaction.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(transaction.status).thenReturn(null);
      when(transaction.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      when(transaction.startChild('ui.load.full_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, transaction);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);

      final anotherRoute = route(RouteSettings(name: 'Another Route'));
      sut.didPush(anotherRoute, null);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(ttidSpan.finish(
              endTimestamp: captureAnyNamed('endTimestamp'),
              status: SpanStatus.deadlineExceeded()))
          .called(1);
      verify(ttfdSpan.finish(
              endTimestamp: captureAnyNamed('endTimestamp'),
              status: SpanStatus.deadlineExceeded()))
          .called(1);
    });

    test(
        'unfinished children will be finished with deadline_exceeded on didPop',
        () async {
      final currentRoute = route(RouteSettings(name: 'Current Route'));

      final hub = _MockHub();
      final span = getMockSentryTracer(finished: false) as SentryTracer;
      final mockChildA = MockSentrySpan();
      final mockChildB = MockSentrySpan();
      when(span.children).thenReturn([
        mockChildB,
        mockChildA,
      ]);
      when(mockChildA.finished).thenReturn(false);
      when(mockChildB.finished).thenReturn(false);
      when(mockChildA.context).thenReturn(SentrySpanContext(
          operation: SentrySpanOperations.uiTimeToInitialDisplay));
      when(mockChildB.context).thenReturn(SentrySpanContext(
          operation: SentrySpanOperations.uiTimeToFullDisplay));
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.status).thenReturn(null);
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      // Push to new screen, e.g root to user screen
      sut.didPush(currentRoute, null);

      // Pop back e.g user to root screen
      sut.didPop(currentRoute, null);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(mockChildA.finish(
              endTimestamp: captureAnyNamed('endTimestamp'),
              status: SpanStatus.deadlineExceeded()))
          .called(1);
      verify(mockChildB.finish(
              endTimestamp: captureAnyNamed('endTimestamp'),
              status: SpanStatus.deadlineExceeded()))
          .called(1);
    });

    test('route arguments are set on transaction', () async {
      final arguments = {'foo': 'bar'};
      final currentRoute = route(RouteSettings(
        name: 'Current Route',
        arguments: arguments,
      ));

      final hub = _MockHub();
      final span = getMockSentryTracer();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.status).thenReturn(null);
      when(span.finished).thenReturn(false);
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(currentRoute, null);
      await sut.completedDisplayTracking?.future;

      verify(span.setData('route_settings_arguments', arguments));
    });

    test('root route does not start transaction', () async {
      final rootRoute = route(RouteSettings(name: '/'));

      final hub = _MockHub();
      final span = getMockSentryTracer();
      when(span.context).thenReturn(SentrySpanContext(operation: 'op'));
      when(span.finished).thenReturn(false);
      when(span.status).thenReturn(SpanStatus.ok());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(hub: hub);

      sut.didPush(rootRoute, null);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      verifyNever(hub.startTransactionWithContext(
        any,
        startTimestamp: anyNamed('startTimestamp'),
        waitForChildren: true,
        autoFinishAfter: anyNamed('autoFinishAfter'),
        trimEnd: true,
        onFinish: anyNamed('onFinish'),
      ));

      hub.configureScope((scope) {
        expect(scope.span, null);
      });
    });

    test('didPush sets current route name', () async {
      const name = 'Current Route';
      final currentRoute = route(RouteSettings(name: name));

      const op = 'navigation';
      final hub = _MockHub();
      final span = getMockSentryTracer(name: name);
      when(span.context).thenReturn(SentrySpanContext(operation: op));
      when(span.finished).thenReturn(false);
      when(span.status).thenReturn(SpanStatus.ok());
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(
        hub: hub,
        autoFinishAfter: Duration(seconds: 5),
      );

      sut.didPush(currentRoute, null);
      await sut.completedDisplayTracking?.future;

      expect(SentryNavigatorObserver.currentRouteName, 'Current Route');
    });

    test('didReplace sets new route name', () {
      const oldRouteName = 'Old Route';
      final oldRoute = route(RouteSettings(name: oldRouteName));
      const newRouteName = 'New Route';
      final newRoute = route(RouteSettings(name: newRouteName));

      const op = 'navigation';
      final hub = _MockHub();
      final span = getMockSentryTracer(name: oldRouteName);
      when(span.context).thenReturn(SentrySpanContext(operation: op));
      when(span.finished).thenReturn(false);
      when(span.status).thenReturn(SpanStatus.ok());
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(
        hub: hub,
        autoFinishAfter: Duration(seconds: 5),
      );

      sut.didPush(oldRoute, null);
      sut.didReplace(newRoute: newRoute, oldRoute: oldRoute);

      expect(SentryNavigatorObserver.currentRouteName, 'New Route');
    });

    test('popRoute sets previous route name', () {
      const oldRouteName = 'Old Route';
      final oldRoute = route(RouteSettings(name: oldRouteName));
      const newRouteName = 'New Route';
      final newRoute = route(RouteSettings(name: newRouteName));

      const op = 'navigation';
      final hub = _MockHub();
      final span = getMockSentryTracer(name: oldRouteName);
      when(span.children).thenReturn([]);
      when(span.context).thenReturn(SentrySpanContext(operation: op));
      when(span.status).thenReturn(null);
      when(span.finished).thenReturn(false);
      when(span.startChild('ui.load.initial_display',
              description: anyNamed('description'),
              startTimestamp: anyNamed('startTimestamp')))
          .thenReturn(NoOpSentrySpan());
      _whenAnyStart(hub, span);

      final sut = fixture.getSut(
        hub: hub,
        autoFinishAfter: Duration(seconds: 5),
      );

      sut.didPush(oldRoute, null);
      sut.didPop(newRoute, oldRoute);

      expect(SentryNavigatorObserver.currentRouteName, 'Old Route');
    });
  });

  group('RouteObserverBreadcrumb', () {
    test('happy path with string route agrument', () {
      const fromRouteSettings = RouteSettings(
        name: 'from',
        arguments: 'PageTitle',
      );

      const toRouteSettings = RouteSettings(
        name: 'to',
        arguments: 'PageTitle2',
      );

      final breadcrumb = RouteObserverBreadcrumb(
        navigationType: 'didPush',
        from: fromRouteSettings,
        to: toRouteSettings,
        data: {'foo': 'bar'},
      );

      expect(breadcrumb.category, 'navigation');
      expect(breadcrumb.data, <String, dynamic>{
        'state': 'didPush',
        'from': 'from',
        'from_arguments': 'PageTitle',
        'to': 'to',
        'to_arguments': 'PageTitle2',
        'data': {'foo': 'bar'},
      });
    });

    test('happy path with map route agrument', () {
      const fromRouteSettings = RouteSettings(
        name: 'from',
        arguments: 'PageTitle',
      );

      const toRouteSettings = RouteSettings(
        name: 'to',
        arguments: {
          'foo': 123,
          'bar': 'foobar',
        },
      );

      final breadcrumb = RouteObserverBreadcrumb(
        navigationType: 'didPush',
        from: fromRouteSettings,
        to: toRouteSettings,
      );

      expect(breadcrumb.category, 'navigation');
      expect(breadcrumb.data, <String, dynamic>{
        'state': 'didPush',
        'from': 'from',
        'from_arguments': 'PageTitle',
        'to': 'to',
        'to_arguments': {
          'foo': '123',
          'bar': 'foobar',
        },
      });
    });

    test('routes are null', () {
      // both routes are null
      final breadcrumb = RouteObserverBreadcrumb(
        navigationType: 'didPush',
        from: null,
        to: null,
      );

      expect(breadcrumb.category, 'navigation');
      expect(breadcrumb.data, <String, dynamic>{
        'state': 'didPush',
      });
    });

    test('route arguments are null', () {
      const fromRouteSettings = RouteSettings(
        name: 'from',
      );

      const toRouteSettings = RouteSettings(
        name: 'to',
        arguments: null,
      );

      // both routes are null
      final breadcrumb = RouteObserverBreadcrumb(
        navigationType: 'didPush',
        from: fromRouteSettings,
        to: toRouteSettings,
      );

      expect(breadcrumb.category, 'navigation');
      expect(breadcrumb.data, <String, dynamic>{
        'state': 'didPush',
        'from': 'from',
        'to': 'to',
      });
    });

    test('route names are null', () {
      const fromRouteSettings = RouteSettings(name: null, arguments: 'foo');

      const toRouteSettings = RouteSettings(
        name: null,
        arguments: {
          'foo': 123,
        },
      );

      // both routes are null
      final breadcrumb = RouteObserverBreadcrumb(
        navigationType: 'didPush',
        from: fromRouteSettings,
        to: toRouteSettings,
      );

      expect(breadcrumb.category, 'navigation');
      expect(breadcrumb.data, <String, dynamic>{
        'state': 'didPush',
        'from_arguments': 'foo',
        'to_arguments': {
          'foo': '123',
        },
      });
    });
  });

  group('SentryNavigatorObserver', () {
    RouteSettings routeSettings(String? name, [Object? arguments]) =>
        RouteSettings(name: name, arguments: arguments);

    test('Test recording of Breadcrumbs', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(hub: hub);

      final to = routeSettings('to', 'foobar');
      final previous = routeSettings('previous', 'foobar');

      observer.didPush(route(to), route(previous));

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        RouteObserverBreadcrumb(
          navigationType: 'didPush',
          from: previous,
          to: to,
        ).data,
      );
    });

    test('No arguments', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(hub: hub);

      final to = routeSettings('to');
      final previous = routeSettings('previous');

      observer.didPush(route(to), route(previous));

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        RouteObserverBreadcrumb(
          navigationType: 'didPush',
          from: previous,
          to: to,
        ).data,
      );
    });

    test('No arguments & no name', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(hub: hub);

      final to = route(null);
      final previous = route(null);

      observer.didReplace(newRoute: to, oldRoute: previous);

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        RouteObserverBreadcrumb(
          navigationType: 'didReplace',
        ).data,
      );
    });

    test('No RouteSettings', () {
      PageRoute<dynamic> route() => PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => Container(),
          );

      final hub = _MockHub();
      final observer = fixture.getSut(hub: hub);
      when(hub.getSpan()).thenReturn(NoOpSentrySpan());

      final to = route();
      final previous = route();

      observer.didPop(to, previous);

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        RouteObserverBreadcrumb(
          navigationType: 'didPop',
        ).data,
      );
    });

    test('route name as transaction', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(
        hub: hub,
        setRouteNameAsTransaction: true,
      );

      final to = routeSettings('to');
      final previous = routeSettings('previous');

      observer.didPush(route(to), route(previous));
      expect(hub.scope.transaction, 'to');

      observer.didPop(route(to), route(previous));
      expect(hub.scope.transaction, 'previous');

      observer.didReplace(newRoute: route(to), oldRoute: route(previous));
      expect(hub.scope.transaction, 'to');
    });

    test('route name does nothing if null', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(
        hub: hub,
        setRouteNameAsTransaction: true,
      );

      hub.scope.transaction = 'foo bar';

      final to = routeSettings(null);
      final previous = routeSettings(null);

      observer.didPush(route(to), route(previous));
      expect(hub.scope.transaction, 'foo bar');
    });

    test('disabled route as transaction', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer =
          fixture.getSut(hub: hub, setRouteNameAsTransaction: false);

      final to = routeSettings('to');
      final previous = routeSettings('previous');

      observer.didPush(route(to), route(previous));
      expect(hub.scope.transaction, null);

      observer.didPop(route(to), route(previous));
      expect(hub.scope.transaction, null);

      observer.didReplace(newRoute: route(to), oldRoute: route(previous));
      expect(hub.scope.transaction, null);
    });

    test('modifying route settings', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(
          hub: hub,
          routeNameExtractor: (settings) {
            if (settings != null && settings.name == 'to') {
              return settings.copyWith(name: 'changed_to');
            }
            return settings;
          });

      final to = routeSettings('to', 'foobar');
      final previous = routeSettings('previous', 'foobar');

      observer.didPush(route(to), route(previous));

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        RouteObserverBreadcrumb(
          navigationType: 'didPush',
          from: previous,
          to: to.copyWith(name: 'changed_to'),
        ).data,
      );
    });

    test('add additional data', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(
          hub: hub,
          additionalInfoProvider: (from, to) {
            return <String, dynamic>{'foo': 'bar'};
          });

      final to = routeSettings('to', 'foobar');
      final previous = routeSettings('previous', 'foobar');

      observer.didPush(route(to), route(previous));

      final dynamic breadcrumb =
          verify(hub.addBreadcrumb(captureAny)).captured.single as Breadcrumb;
      expect(
        breadcrumb.data,
        RouteObserverBreadcrumb(
          navigationType: 'didPush',
          from: previous,
          to: to.copyWith(name: 'to'),
          data: {'foo': 'bar'},
        ).data,
      );
    });

    test('route name as transaction with routeNameExtractor', () {
      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());
      final observer = fixture.getSut(
          hub: hub,
          setRouteNameAsTransaction: true,
          routeNameExtractor: (settings) =>
              settings?.copyWith(name: '${settings.name}_test'));

      final to = routeSettings('to');
      final previous = routeSettings('previous');

      observer.didPush(route(to), route(previous));
      expect(hub.scope.transaction, 'to_test');

      observer.didPop(route(to), route(previous));
      expect(hub.scope.transaction, 'previous_test');

      observer.didReplace(newRoute: route(to), oldRoute: route(previous));
      expect(hub.scope.transaction, 'to_test');
    });

    test('ignores Route and prevents recognition of this route for didPush',
        () async {
      final firstRoute = route(RouteSettings(name: 'default'));
      final secondRoute = route(RouteSettings(name: 'testRoute'));

      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());

      final sut = fixture.getSut(hub: hub, ignoreRoutes: ["testRoute"]);

      sut.didPush(firstRoute, null);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
      sut.didPush(secondRoute, firstRoute);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
      sut.didPush(firstRoute, secondRoute);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
    });

    test('ignores Route and prevents recognition of this route for didPop',
        () async {
      final firstRoute = route(RouteSettings(name: 'default'));
      final secondRoute = route(RouteSettings(name: 'testRoute'));

      final hub = _MockHub();
      _whenAnyStart(hub, NoOpSentrySpan());

      final sut = fixture.getSut(hub: hub, ignoreRoutes: ["testRoute"]);

      sut.didPush(firstRoute, null);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
      sut.didPush(secondRoute, firstRoute);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
      sut.didPop(firstRoute, secondRoute);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
    });

    test('ignores Route and prevents recognition of this route for didReplace',
        () async {
      final firstRoute = route(RouteSettings(name: 'default'));
      final secondRoute = route(RouteSettings(name: 'testRoute'));

      final hub = _MockHub();

      final sut = fixture.getSut(hub: hub, ignoreRoutes: ["testRoute"]);

      sut.didReplace(newRoute: firstRoute);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
      sut.didReplace(newRoute: secondRoute, oldRoute: firstRoute);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
      sut.didReplace(newRoute: firstRoute, oldRoute: secondRoute);
      expect(
          SentryNavigatorObserver.currentRouteName, firstRoute.settings.name);
    });
  });
}

class Fixture {
  late TimeToInitialDisplayTracker timeToInitialDisplayTracker;
  late TimeToFullDisplayTracker timeToFullDisplayTracker;

  SentryNavigatorObserver getSut({
    required Hub hub,
    bool enableAutoTransactions = true,
    Duration autoFinishAfter = const Duration(seconds: 1),
    bool setRouteNameAsTransaction = false,
    RouteNameExtractor? routeNameExtractor,
    AdditionalInfoExtractor? additionalInfoProvider,
    List<String>? ignoreRoutes,
  }) {
    final frameCallbackHandler = FakeFrameCallbackHandler(
        postFrameCallbackDelay: Duration(milliseconds: 10));
    timeToInitialDisplayTracker = TimeToInitialDisplayTracker(
      frameCallbackHandler: frameCallbackHandler,
    );
    timeToFullDisplayTracker = TimeToFullDisplayTracker(
      endTimestampProvider: () => timeToInitialDisplayTracker.endTimestamp,
    );
    final options = hub.options;
    if (options is SentryFlutterOptions) {
      options.timeToDisplayTracker = TimeToDisplayTracker(
        ttidTracker: timeToInitialDisplayTracker,
        ttfdTracker: timeToFullDisplayTracker,
        options: hub.options as SentryFlutterOptions,
      );
    }
    return SentryNavigatorObserver(
      hub: hub,
      enableAutoTransactions: enableAutoTransactions,
      autoFinishAfter: autoFinishAfter,
      setRouteNameAsTransaction: setRouteNameAsTransaction,
      routeNameExtractor: routeNameExtractor,
      additionalInfoProvider: additionalInfoProvider,
      ignoreRoutes: ignoreRoutes,
    );
  }

  SentrySpanContext mockContext() {
    return SentrySpanContext(operation: 'op');
  }
}

class _MockHub extends MockHub {
  @override
  final options = defaultTestOptions();

  @override
  late final scope = Scope(options);

  @override
  FutureOr<void> configureScope(ScopeCallback? callback) async {
    await callback?.call(scope);
  }
}

MockSentryTracer getMockSentryTracer({String? name, bool? finished}) {
  final tracer = MockSentryTracer();
  when(tracer.name).thenReturn(name ?? 'name');
  when(tracer.finished).thenReturn(finished ?? true);
  return tracer;
}

extension RouteSettingsExtensions on RouteSettings {
  /// Creates a copy of this route settings object with the given fields
  /// replaced with the new values.
  /// Flutter 3.6 beta removed copyWith but we use it for testing
  RouteSettings copyWith({
    String? name,
    Object? arguments,
  }) {
    return RouteSettings(
      name: name ?? this.name,
      arguments: arguments ?? this.arguments,
    );
  }
}
