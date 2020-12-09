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
      key: 'key1',
      name: 'name1',
      version: 'version1',
      rawDescription: 'rawDescription1',
    );

    expect('key1', copy.key);
    expect('name1', copy.name);
    expect('version1', copy.version);
    expect('rawDescription1', copy.rawDescription);
  });
}

SentryRuntime _generate() => SentryRuntime(
      key: 'key',
      name: 'name',
      version: 'version',
      rawDescription: 'rawDescription',
    );
