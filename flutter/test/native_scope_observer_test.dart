@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/native/native_scope_observer.dart';

import 'mocks.mocks.dart';

void main() {
  late MockSentryNativeBinding mock;
  late NativeScopeObserver sut;

  setUp(() {
    mock = MockSentryNativeBinding();
    sut = NativeScopeObserver(mock);
  });

  test('addBreadcrumbCalls', () async {
    final breadcrumb = Breadcrumb();
    await sut.addBreadcrumb(breadcrumb);

    expect(verify(mock.addBreadcrumb(captureAny)).captured.single, breadcrumb);
  });

  test('clearBreadcrumbsCalls', () async {
    await sut.clearBreadcrumbs();

    verify(mock.clearBreadcrumbs()).called(1);
  });

  test('removeContextsCalls', () async {
    await sut.removeContexts('fixture-key');

    expect(
        verify(mock.removeContexts(captureAny)).captured.single, 'fixture-key');
  });

  test('removeExtraCalls', () async {
    await sut.removeExtra('fixture-key');

    expect(verify(mock.removeExtra(captureAny)).captured.single, 'fixture-key');
  });

  test('removeTagCalls', () async {
    await sut.removeTag('fixture-key');

    expect(verify(mock.removeTag(captureAny)).captured.single, 'fixture-key');
  });

  test('setContextsCalls', () async {
    await sut.setContexts('fixture-key', 'fixture-value');

    verify(mock.setContexts('fixture-key', 'fixture-value')).called(1);
  });

  test('setExtraCalls', () async {
    await sut.setExtra('fixture-key', 'fixture-value');

    verify(mock.setExtra('fixture-key', 'fixture-value')).called(1);
  });

  test('setTagCalls', () async {
    await sut.setTag('fixture-key', 'fixture-value');

    verify(mock.setTag('fixture-key', 'fixture-value')).called(1);
  });

  test('setUserCalls', () async {
    final user = SentryUser(id: 'foo bar');
    await sut.setUser(user);

    expect(verify(mock.setUser(captureAny)).captured.single, user);
  });
}
