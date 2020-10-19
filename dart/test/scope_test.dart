import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  final fixture = Fixture();

  test('sets $SeverityLevel', () {
    final sut = fixture.getSut();

    sut.level = SeverityLevel.debug;

    expect(sut.level, SeverityLevel.debug);
  });

  test('sets transaction', () {
    final sut = fixture.getSut();

    sut.transaction = 'test';

    expect(sut.transaction, 'test');
  });

  test('sets $User', () {
    final sut = fixture.getSut();

    final user = User(id: 'test');
    sut.user = user;

    expect(sut.user, user);
  });

  test('sets fingerprint', () {
    final sut = fixture.getSut();

    final fingerprints = ['test'];
    sut.fingerprint = fingerprints;

    expect(sut.fingerprint, fingerprints);
  });

  test('adds $Breadcrumb', () {
    final sut = fixture.getSut();

    final breadcrumb = Breadcrumb('test log', DateTime.utc(2019));
    sut.addBreadcrumb(breadcrumb);

    expect(sut.breadcrumbs.last, breadcrumb);
  });

  test('respects max $Breadcrumb', () {
    final maxBreadcrumbs = 2;
    final sut = fixture.getSut(maxBreadcrumbs: maxBreadcrumbs);

    final breadcrumb1 = Breadcrumb('test log', DateTime.utc(2019));
    final breadcrumb2 = Breadcrumb('test log', DateTime.utc(2019));
    final breadcrumb3 = Breadcrumb('test log', DateTime.utc(2019));
    sut.addBreadcrumb(breadcrumb1);
    sut.addBreadcrumb(breadcrumb2);
    sut.addBreadcrumb(breadcrumb3);

    expect(sut.breadcrumbs.length, maxBreadcrumbs);
  });

  test('rotates $Breadcrumb', () {
    final sut = fixture.getSut(maxBreadcrumbs: 2);

    final breadcrumb1 = Breadcrumb('test log', DateTime.utc(2019));
    final breadcrumb2 = Breadcrumb('test log', DateTime.utc(2019));
    final breadcrumb3 = Breadcrumb('test log', DateTime.utc(2019));
    sut.addBreadcrumb(breadcrumb1);
    sut.addBreadcrumb(breadcrumb2);
    sut.addBreadcrumb(breadcrumb3);

    expect(sut.breadcrumbs.first, breadcrumb2);

    expect(sut.breadcrumbs.last, breadcrumb3);
  });

  test('empty $Breadcrumb list', () {
    final maxBreadcrumbs = 0;
    final sut = fixture.getSut(maxBreadcrumbs: maxBreadcrumbs);

    final breadcrumb1 = Breadcrumb('test log', DateTime.utc(2019));
    sut.addBreadcrumb(breadcrumb1);

    expect(sut.breadcrumbs.length, maxBreadcrumbs);
  });

  test('clears $Breadcrumb list', () {
    final sut = fixture.getSut();

    final breadcrumb1 = Breadcrumb('test log', DateTime.utc(2019));
    sut.addBreadcrumb(breadcrumb1);
    sut.clear();

    expect(sut.breadcrumbs.length, 0);
  });

  test('sets tag', () {
    final sut = fixture.getSut();

    sut.setTag('test', 'test');

    expect(sut.tags['test'], 'test');
  });

  test('removes tag', () {
    final sut = fixture.getSut();

    sut.setTag('test', 'test');
    sut.removeTag('test');

    expect(sut.tags['test'], null);
  });

  test('sets extra', () {
    final sut = fixture.getSut();

    sut.setExtra('test', 'test');

    expect(sut.extra['test'], 'test');
  });

  test('removes extra', () {
    final sut = fixture.getSut();

    sut.setExtra('test', 'test');
    sut.removeExtra('test');

    expect(sut.extra['test'], null);
  });

  test('clears $Scope', () {
    final sut = fixture.getSut();

    final breadcrumb1 = Breadcrumb('test log', DateTime.utc(2019));
    sut.addBreadcrumb(breadcrumb1);

    sut.level = SeverityLevel.debug;
    sut.transaction = 'test';

    final user = User(id: 'test');
    sut.user = user;

    final fingerprints = ['test'];
    sut.fingerprint = fingerprints;

    sut.setTag('test', 'test');
    sut.setExtra('test', 'test');

    sut.clear();

    expect(sut.breadcrumbs.length, 0);

    expect(sut.level, null);

    expect(sut.transaction, null);

    expect(sut.user, null);

    expect(sut.fingerprint, null);

    expect(sut.tags.length, 0);

    expect(sut.extra.length, 0);
  });

  test('clones', () {
    final sut = fixture.getSut();
    final clone = sut.clone();
    expect(sut.user, clone.user);
    expect(sut.transaction, clone.transaction);
    expect(sut.extra, clone.extra);
    expect(sut.tags, clone.tags);
    expect(sut.breadcrumbs, clone.breadcrumbs);
    expect(ListEquality().equals(sut.fingerprint, clone.fingerprint), true);
  });
}

class Fixture {
  Scope getSut({int maxBreadcrumbs = 100}) {
    final options = SentryOptions();
    options.maxBreadcrumbs = maxBreadcrumbs;
    return Scope(options);
  }
}
