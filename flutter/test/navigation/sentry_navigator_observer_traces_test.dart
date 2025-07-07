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

  test('didPush starts a new trace and transaction uses the new trace id', () {
    final fromRoute = _route(RouteSettings(name: 'From Route'));
    final toRoute = _route(RouteSettings(name: 'To Route'));

    final oldTraceId = fixture.hub.scope.propagationContext.traceId;

    final sut = fixture.getSut();
    sut.didPush(toRoute, fromRoute);

    // Verify new trace was started
    final newTraceId = fixture.hub.scope.propagationContext.traceId;
    expect(oldTraceId, isNot(newTraceId));

    // Verify the transaction uses the new trace ID
    final transaction = fixture.hub.scope.span;
    expect(transaction?.context.traceId, equals(newTraceId));
  });

  // Note: didPop does not create a transaction
  test('didPop starts a new trace', () {
    final fromRoute = _route(RouteSettings(name: 'From Route'));
    final toRoute = _route(RouteSettings(name: 'To Route'));
    final oldTraceId = fixture.hub.scope.propagationContext.traceId;
    final oldSampleRand = fixture.hub.scope.propagationContext.sampleRand;

    final sut = fixture.getSut();
    sut.didPop(toRoute, fromRoute);

    final newTraceId = fixture.hub.scope.propagationContext.traceId;
    final newSampleRand = fixture.hub.scope.propagationContext.sampleRand;
    expect(oldTraceId, isNot(newTraceId));
    expect(oldSampleRand, isNot(newSampleRand));
  });

  // Note: didReplace does not create a transaction
  test('didReplace starts a new trace', () {
    final fromRoute = _route(RouteSettings(name: 'From Route'));
    final toRoute = _route(RouteSettings(name: 'To Route'));
    final oldTraceId = fixture.hub.scope.propagationContext.traceId;
    final oldSampleRand = fixture.hub.scope.propagationContext.sampleRand;

    final sut = fixture.getSut();
    sut.didReplace(newRoute: toRoute, oldRoute: fromRoute);

    final newTraceId = fixture.hub.scope.propagationContext.traceId;
    final newSampleRand = fixture.hub.scope.propagationContext.sampleRand;
    expect(oldTraceId, isNot(newTraceId));
    expect(oldSampleRand, isNot(newSampleRand));
  });
}

PageRoute<dynamic> _route(RouteSettings? settings) => PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => Container(),
      settings: settings,
    );

class Fixture {
  final options = defaultTestOptions()..tracesSampleRate = 1.0;
  late final mockHub = MockHub();
  late final hub = Hub(options);
  late final mockScope = Scope(options);

  Fixture() {
    // Set up the mockHub with proper scope
    when(mockHub.options).thenReturn(options);
    when(mockHub.scope).thenReturn(mockScope);
  }

  SentryNavigatorObserver getSut({Hub? hub}) {
    hub ??= this.hub;
    if (hub == mockHub) {
      when(mockHub.options).thenReturn(options);
    }
    return SentryNavigatorObserver(hub: hub);
  }
}
