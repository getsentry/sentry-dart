// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('SentryNavigatorObserver', () {
    group('when starting traces on navigation is enabled (default)', () {
      test('didPush should not start a new trace on root', () {
        final to = _route(RouteSettings(name: '/'));
        final beforeTraceId = fixture.hub.scope.propagationContext.traceId;

        fixture.getSut().didPush(to, null);

        final afterTraceId = fixture.hub.scope.propagationContext.traceId;
        expect(afterTraceId, equals(beforeTraceId));
      });

      test('didPush should start a new trace', () {
        final from = _route(RouteSettings(name: 'From Route'));
        final to = _route(RouteSettings(name: 'To Route'));
        final beforeTraceId = fixture.hub.scope.propagationContext.traceId;

        fixture.getSut().didPush(to, from);

        final afterTraceId = fixture.hub.scope.propagationContext.traceId;
        expect(afterTraceId, isNot(beforeTraceId));
      });

      test('didPop should start a new trace', () {
        final from = _route(RouteSettings(name: 'From Route'));
        final to = _route(RouteSettings(name: 'To Route'));
        final beforeTraceId = fixture.hub.scope.propagationContext.traceId;

        fixture.getSut().didPop(to, from);

        final afterTraceId = fixture.hub.scope.propagationContext.traceId;
        expect(afterTraceId, isNot(beforeTraceId));
      });

      test('didReplace should start a new trace', () {
        final from = _route(RouteSettings(name: 'From Route'));
        final to = _route(RouteSettings(name: 'To Route'));
        final beforeTraceId = fixture.hub.scope.propagationContext.traceId;

        fixture.getSut().didReplace(newRoute: to, oldRoute: from);

        final afterTraceId = fixture.hub.scope.propagationContext.traceId;
        expect(afterTraceId, isNot(beforeTraceId));
      });

      group('execution order', () {
        void _stubHub() {
          when(fixture.mockHub.generateNewTrace()).thenReturn(null);
          when(fixture.mockHub.configureScope(any))
              .thenAnswer((_) => Future.value());
          when(fixture.mockHub.startTransactionWithContext(
            any,
            bindToScope: anyNamed('bindToScope'),
            waitForChildren: anyNamed('waitForChildren'),
            autoFinishAfter: anyNamed('autoFinishAfter'),
            trimEnd: anyNamed('trimEnd'),
            onFinish: anyNamed('onFinish'),
            customSamplingContext: anyNamed('customSamplingContext'),
            startTimestamp: anyNamed('startTimestamp'),
          )).thenReturn(NoOpSentrySpan());
        }

        test(
            'didPush should call generateNewTrace beforeTraceId starting the transaction',
            () {
          final from = _route(RouteSettings(name: 'From Route'));
          final to = _route(RouteSettings(name: 'To Route'));

          _stubHub();
          final sut = fixture.getSut(hub: fixture.mockHub);
          sut.didPush(to, from);

          verifyInOrder([
            fixture.mockHub.generateNewTrace(),
            fixture.mockHub.startTransactionWithContext(
              any,
              bindToScope: anyNamed('bindToScope'),
              waitForChildren: anyNamed('waitForChildren'),
              autoFinishAfter: anyNamed('autoFinishAfter'),
              trimEnd: anyNamed('trimEnd'),
              onFinish: anyNamed('onFinish'),
              customSamplingContext: anyNamed('customSamplingContext'),
              startTimestamp: anyNamed('startTimestamp'),
            ),
          ]);
        });
      });
    });

    group('when starting traces on navigation is disabled', () {
      test('didPush should not start a new trace', () {
        final from = _route(RouteSettings(name: 'From Route'));
        final to = _route(RouteSettings(name: 'To Route'));
        final beforeTraceId = fixture.hub.scope.propagationContext.traceId;

        fixture.getSut(enableNewTraceOnNavigation: false).didPush(to, from);

        final afterTraceId = fixture.hub.scope.propagationContext.traceId;
        expect(afterTraceId, equals(beforeTraceId));
      });

      test('didPop should not start a new trace', () {
        final from = _route(RouteSettings(name: 'From Route'));
        final to = _route(RouteSettings(name: 'To Route'));
        final beforeTraceId = fixture.hub.scope.propagationContext.traceId;

        fixture.getSut(enableNewTraceOnNavigation: false).didPop(to, from);

        final afterTraceId = fixture.hub.scope.propagationContext.traceId;
        expect(afterTraceId, equals(beforeTraceId));
      });

      test('didReplace should not start a new trace', () {
        final from = _route(RouteSettings(name: 'From Route'));
        final to = _route(RouteSettings(name: 'To Route'));
        final beforeTraceId = fixture.hub.scope.propagationContext.traceId;

        fixture
            .getSut(enableNewTraceOnNavigation: false)
            .didReplace(newRoute: to, oldRoute: from);

        final afterTraceId = fixture.hub.scope.propagationContext.traceId;
        expect(afterTraceId, equals(beforeTraceId));
      });
    });
  });
}

PageRoute<dynamic> _route(RouteSettings? settings) => PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => Container(),
      settings: settings,
    );

class Fixture {
  final options = defaultTestOptions();
  late final mockHub = MockHub();
  late final hub = Hub(options);

  SentryNavigatorObserver getSut({
    Hub? hub,
    bool enableNewTraceOnNavigation = true,
  }) {
    hub ??= this.hub;
    if (hub == mockHub) {
      when(mockHub.options).thenReturn(options);
    }
    return SentryNavigatorObserver(
      hub: hub,
      enableNewTraceOnNavigation: enableNewTraceOnNavigation,
    );
  }
}
