// ignore_for_file: inference_failure_on_function_invocation

@TestOn('vm')

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/sentry_native.dart';
import 'package:sentry_flutter/src/sentry_native_channel.dart';
import 'mocks.mocks.dart';

void main() {
  group('$SentryNative', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('fetchNativeAppStart', () async {
      final map = <String, dynamic>{
        'appStartTime': 0.1,
        'isColdStart': true,
      };
      final future = Future.value(map);

      when(fixture.methodChannel
              .invokeMapMethod<String, dynamic>('fetchNativeAppStart'))
          .thenAnswer((_) => future);

      final sut = fixture.getSut();
      final actual = await sut.fetchNativeAppStart();

      expect(actual?.appStartTime, 0.1);
      expect(actual?.isColdStart, true);
    });

    test('setUser', () async {
      when(fixture.methodChannel.invokeMethod('setUser', {'user': null}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.setUser(null);

      verify(fixture.methodChannel.invokeMethod('setUser', {'user': null}));
    });

    test('addBreadcrumb', () async {
      final breadcrumb = Breadcrumb();
      when(fixture.methodChannel.invokeMethod(
              'addBreadcrumb', {'breadcrumb': breadcrumb.toJson()}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.addBreadcrumb(breadcrumb);

      verify(fixture.methodChannel
          .invokeMethod('addBreadcrumb', {'breadcrumb': breadcrumb.toJson()}));
    });

    test('clearBreadcrumbs', () async {
      when(fixture.methodChannel.invokeMethod('clearBreadcrumbs'))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.clearBreadcrumbs();

      verify(fixture.methodChannel.invokeMethod('clearBreadcrumbs'));
    });

    test('setContexts', () async {
      when(fixture.methodChannel.invokeMethod(
              'setContexts', {'key': 'fixture-key', 'value': 'fixture-value'}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.setContexts('fixture-key', 'fixture-value');

      verify(fixture.methodChannel.invokeMethod(
          'setContexts', {'key': 'fixture-key', 'value': 'fixture-value'}));
    });

    test('removeContexts', () async {
      when(fixture.methodChannel
              .invokeMethod('removeContexts', {'key': 'fixture-key'}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.removeContexts('fixture-key');

      verify(fixture.methodChannel
          .invokeMethod('removeContexts', {'key': 'fixture-key'}));
    });

    test('setExtra', () async {
      when(fixture.methodChannel.invokeMethod(
              'setExtra', {'key': 'fixture-key', 'value': 'fixture-value'}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.setExtra('fixture-key', 'fixture-value');

      verify(fixture.methodChannel.invokeMethod(
          'setExtra', {'key': 'fixture-key', 'value': 'fixture-value'}));
    });

    test('removeExtra', () async {
      when(fixture.methodChannel
              .invokeMethod('removeExtra', {'key': 'fixture-key'}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.removeExtra('fixture-key');

      verify(fixture.methodChannel
          .invokeMethod('removeExtra', {'key': 'fixture-key'}));
    });

    test('setTag', () async {
      when(fixture.methodChannel.invokeMethod(
              'setTag', {'key': 'fixture-key', 'value': 'fixture-value'}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.setTag('fixture-key', 'fixture-value');

      verify(fixture.methodChannel.invokeMethod(
          'setTag', {'key': 'fixture-key', 'value': 'fixture-value'}));
    });

    test('removeTag', () async {
      when(fixture.methodChannel
              .invokeMethod('removeTag', {'key': 'fixture-key'}))
          .thenAnswer((_) => Future.value());

      final sut = fixture.getSut();
      await sut.removeTag('fixture-key');

      verify(fixture.methodChannel
          .invokeMethod('removeTag', {'key': 'fixture-key'}));
    });
  });
}

class Fixture {
  final methodChannel = MockMethodChannel();
  final options = SentryFlutterOptions();

  SentryNativeChannel getSut() {
    return SentryNativeChannel(methodChannel, options);
  }
}
