@TestOn('vm')
library flutter_test;

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_flutter/src/native/native_scope_observer.dart';

import 'mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('addBreadcrumbCalls', () async {
    final sut = fixture.getSut();
    final breadcrumb = Breadcrumb();
    await sut.addBreadcrumb(breadcrumb);

    expect(fixture.mock.breadcrumb, breadcrumb);
    expect(fixture.mock.numberOfAddBreadcrumbCalls, 1);
  });

  test('clearBreadcrumbsCalls', () async {
    final sut = fixture.getSut();
    await sut.clearBreadcrumbs();

    expect(fixture.mock.numberOfClearBreadcrumbsCalls, 1);
  });

  test('removeContextsCalls', () async {
    final sut = fixture.getSut();
    await sut.removeContexts('fixture-key');

    expect(fixture.mock.removeContextsKey, 'fixture-key');
    expect(fixture.mock.numberOfRemoveContextsCalls, 1);
  });

  test('removeExtraCalls', () async {
    final sut = fixture.getSut();
    await sut.removeExtra('fixture-key');

    expect(fixture.mock.removeExtraKey, 'fixture-key');
    expect(fixture.mock.numberOfRemoveExtraCalls, 1);
  });

  test('removeTagCalls', () async {
    final sut = fixture.getSut();
    await sut.removeTag('fixture-key');

    expect(fixture.mock.removeTagKey, 'fixture-key');
    expect(fixture.mock.numberOfRemoveTagCalls, 1);
  });

  test('setContextsCalls', () async {
    final sut = fixture.getSut();
    await sut.setContexts('fixture-key', 'fixture-value');

    expect(fixture.mock.setContextData['fixture-key'], 'fixture-value');
    expect(fixture.mock.numberOfSetContextsCalls, 1);
  });

  test('setExtraCalls', () async {
    final sut = fixture.getSut();
    await sut.setExtra('fixture-key', 'fixture-value');

    expect(fixture.mock.setExtraData['fixture-key'], 'fixture-value');
    expect(fixture.mock.numberOfSetExtraCalls, 1);
  });

  test('setTagCalls', () async {
    final sut = fixture.getSut();
    await sut.setTag('fixture-key', 'fixture-value');

    expect(fixture.mock.setTagsData['fixture-key'], 'fixture-value');
    expect(fixture.mock.numberOfSetTagCalls, 1);
  });

  test('setUserCalls', () async {
    final sut = fixture.getSut();

    final user = SentryUser(id: 'foo bar');
    await sut.setUser(user);

    expect(fixture.mock.sentryUser, user);
    expect(fixture.mock.numberOfSetUserCalls, 1);
  });
}

class Fixture {
  var mock = TestMockSentryNative();

  NativeScopeObserver getSut() {
    final sut = NativeScopeObserver(mock);
    return sut;
  }
}
