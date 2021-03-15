import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith keeps unchanged', () {
    final data = _generate();

    final copy = data.copyWith();

    expect(
      MapEquality().equals(data.toJson(), copy.toJson()),
      true,
    );
  });

  test('copyWith takes new values', () {
    final data = _generate();

    final copy = data.copyWith(
      name: 'name1',
      version: 'version1',
    );

    expect('name1', copy.name);
    expect('version1', copy.version);
  });
}

SentryBrowser _generate() => SentryBrowser(
      name: 'name',
      version: 'version',
    );
