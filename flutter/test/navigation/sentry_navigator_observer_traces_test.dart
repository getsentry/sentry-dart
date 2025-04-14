// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../mocks.dart';

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

  // TODO: test that trace generation happens before instrumentations
}

PageRoute<dynamic> _route(RouteSettings? settings) => PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => Container(),
      settings: settings,
    );

class Fixture {
  final options = defaultTestOptions();
  late final hub = Hub(options);

  SentryNavigatorObserver getSut({Hub? hub}) {
    hub ??= this.hub;
    return SentryNavigatorObserver(hub: hub);
  }
}
