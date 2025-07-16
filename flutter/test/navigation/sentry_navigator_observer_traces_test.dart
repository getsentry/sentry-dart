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

  test('didPush generates a new trace', () {
    final fromRoute = _route(RouteSettings(name: 'From Route'));
    final toRoute = _route(RouteSettings(name: 'To Route'));
    final oldTraceId = fixture.hub.scope.propagationContext.traceId;

    final sut = fixture.getSut();
    sut.didPush(toRoute, fromRoute);

    final newTraceId = fixture.hub.scope.propagationContext.traceId;
    expect(oldTraceId, isNot(newTraceId));
  });

  test('didPop generates a new trace', () {
    final fromRoute = _route(RouteSettings(name: 'From Route'));
    final toRoute = _route(RouteSettings(name: 'To Route'));
    final oldTraceId = fixture.hub.scope.propagationContext.traceId;

    final sut = fixture.getSut();
    sut.didPop(toRoute, fromRoute);

    final newTraceId = fixture.hub.scope.propagationContext.traceId;
    expect(oldTraceId, isNot(newTraceId));
  });

  test('didReplace generates a new trace', () {
    final fromRoute = _route(RouteSettings(name: 'From Route'));
    final toRoute = _route(RouteSettings(name: 'To Route'));
    final oldTraceId = fixture.hub.scope.propagationContext.traceId;

    final sut = fixture.getSut();
    sut.didReplace(newRoute: toRoute, oldRoute: fromRoute);

    final newTraceId = fixture.hub.scope.propagationContext.traceId;
    expect(oldTraceId, isNot(newTraceId));
  });

  group('execution order', () {
    /// Prepares mocks, we don't care about what they exactly do.
    /// We only test the order of execution in this group.
    void _prepareMocks() {
      when(fixture.mockHub.generateNewTrace()).thenAnswer((_) => {});
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

    test('didPush generates a new trace before creating transaction spans', () {
      final fromRoute = _route(RouteSettings(name: 'From Route'));
      final toRoute = _route(RouteSettings(name: 'To Route'));

      _prepareMocks();

      final sut = fixture.getSut(hub: fixture.mockHub);
      sut.didPush(toRoute, fromRoute);
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
}

PageRoute<dynamic> _route(RouteSettings? settings) => PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => Container(),
      settings: settings,
    );

class Fixture {
  final options = defaultTestOptions();
  late final mockHub = MockHub();
  late final hub = Hub(options);

  SentryNavigatorObserver getSut({Hub? hub}) {
    hub ??= this.hub;
    if (hub == mockHub) {
      when(mockHub.options).thenReturn(options);
    }
    return SentryNavigatorObserver(hub: hub);
  }
}
