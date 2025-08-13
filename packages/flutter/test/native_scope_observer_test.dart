@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/native/native_scope_observer.dart';

import 'mocks.mocks.dart';

void main() {
  late final options = SentryOptions();
  late MockSentryNativeBinding mock;
  late NativeScopeObserver sut;

  setUp(() {
    mock = MockSentryNativeBinding();
    sut = NativeScopeObserver(mock, options);
  });

  test('addBreadcrumbCalls', () async {
    when(mock.addBreadcrumb(any)).thenReturn(null);
    final breadcrumb = Breadcrumb();
    await sut.addBreadcrumb(breadcrumb);

    expect(verify(mock.addBreadcrumb(captureAny)).captured.single, breadcrumb);
  });

  test('clearBreadcrumbsCalls', () async {
    when(mock.clearBreadcrumbs()).thenReturn(null);
    await sut.clearBreadcrumbs();

    verify(mock.clearBreadcrumbs()).called(1);
  });

  test('removeContextsCalls', () async {
    when(mock.removeContexts(any)).thenReturn(null);
    await sut.removeContexts('fixture-key');

    expect(
        verify(mock.removeContexts(captureAny)).captured.single, 'fixture-key');
  });

  test('removeExtraCalls', () async {
    when(mock.removeExtra(any)).thenReturn(null);
    await sut.removeExtra('fixture-key');

    expect(verify(mock.removeExtra(captureAny)).captured.single, 'fixture-key');
  });

  test('removeTagCalls', () async {
    when(mock.removeTag(any)).thenReturn(null);
    await sut.removeTag('fixture-key');

    expect(verify(mock.removeTag(captureAny)).captured.single, 'fixture-key');
  });

  test('setContextsCalls', () async {
    when(mock.setContexts(any, any)).thenReturn(null);
    await sut.setContexts('fixture-key', 'fixture-value');

    verify(mock.setContexts('fixture-key', 'fixture-value')).called(1);
  });

  test(
      'setContextsCalls with context object types should call observer with toJson',
      () async {
    when(mock.setContexts(any, any)).thenReturn(null);

    final sentryDevice = SentryDevice(name: 'test-device', batteryLevel: 85.0);
    await sut.setContexts(SentryDevice.type, sentryDevice);
    verify(mock.setContexts(SentryDevice.type, sentryDevice.toJson()))
        .called(1);

    final sentryOperatingSystem =
        SentryOperatingSystem(name: 'test-os', version: '1.0.0');
    await sut.setContexts(SentryOperatingSystem.type, sentryOperatingSystem);
    verify(mock.setContexts(
            SentryOperatingSystem.type, sentryOperatingSystem.toJson()))
        .called(1);

    final sentryApp = SentryApp(name: 'test-app', version: '2.1.0');
    await sut.setContexts(SentryApp.type, sentryApp);
    verify(mock.setContexts(SentryApp.type, sentryApp.toJson())).called(1);

    final sentryBrowser =
        SentryBrowser(name: 'test-browser', version: '100.0.0');
    await sut.setContexts(SentryBrowser.type, sentryBrowser);
    verify(mock.setContexts(SentryBrowser.type, sentryBrowser.toJson()))
        .called(1);

    final sentryCulture =
        SentryCulture(locale: 'en-US', timezone: 'America/New_York');
    await sut.setContexts(SentryCulture.type, sentryCulture);
    verify(mock.setContexts(SentryCulture.type, sentryCulture.toJson()))
        .called(1);

    final sentryGpu = SentryGpu(name: 'test-gpu', id: 1234);
    await sut.setContexts(SentryGpu.type, sentryGpu);
    verify(mock.setContexts(SentryGpu.type, sentryGpu.toJson())).called(1);

    final sentryTraceContext = SentryTraceContext(operation: 'test-operation');
    await sut.setContexts(SentryTraceContext.type, sentryTraceContext);
    verify(mock.setContexts(
            SentryTraceContext.type, sentryTraceContext.toJson()))
        .called(1);

    final sentryRuntime = SentryRuntime(name: 'test-runtime');
    await sut.setContexts(SentryRuntime.type, sentryRuntime);
    verify(mock.setContexts(SentryRuntime.type, sentryRuntime.toJson()))
        .called(1);

    final sentryResponse = SentryResponse(statusCode: 200);
    await sut.setContexts(SentryResponse.type, sentryResponse);
    verify(mock.setContexts(SentryResponse.type, sentryResponse.toJson()))
        .called(1);

    final sentryFeedback = SentryFeedback(message: 'test-message');
    await sut.setContexts(SentryFeedback.type, sentryFeedback);
    verify(mock.setContexts(SentryFeedback.type, sentryFeedback.toJson()))
        .called(1);

    final sentryFeatureFlags = SentryFeatureFlags(values: [
      SentryFeatureFlag(flag: 'test-flag', result: true),
    ]);
    await sut.setContexts(SentryFeatureFlags.type, sentryFeatureFlags);
    verify(mock.setContexts(
            SentryFeatureFlags.type, sentryFeatureFlags.toJson()))
        .called(1);
  });

  test('setExtraCalls', () async {
    when(mock.setExtra(any, any)).thenReturn(null);
    await sut.setExtra('fixture-key', 'fixture-value');

    verify(mock.setExtra('fixture-key', 'fixture-value')).called(1);
  });

  test('setTagCalls', () async {
    when(mock.setTag(any, any)).thenReturn(null);
    await sut.setTag('fixture-key', 'fixture-value');

    verify(mock.setTag('fixture-key', 'fixture-value')).called(1);
  });

  test('setUserCalls', () async {
    when(mock.setUser(any)).thenReturn(null);

    final user = SentryUser(id: 'foo bar');
    await sut.setUser(user);

    expect(verify(mock.setUser(captureAny)).captured.single, user);
  });
}
