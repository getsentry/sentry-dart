import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith keeps unchanged', () {
    final data = _generate();

    final copy = data.copyWith();

    expect(data.toJson(), copy.toJson());
  });

  test('copyWith takes new values', () {
    final data = _generate();

    final packages = [SentryPackage('name1', 'version1')];
    final integrations = ['test1'];

    final copy = data.copyWith(
      name: 'name1',
      version: 'version1',
      integrations: integrations,
      packages: packages,
    );

    expect(
      ListEquality().equals(integrations, copy.integrations),
      true,
    );
    expect(
      ListEquality().equals(packages, copy.packages),
      true,
    );
    expect('name1', copy.name);
    expect('version1', copy.version);
  });
}

SdkVersion _generate() => SdkVersion(
      name: 'name',
      version: 'version',
      integrations: ['test'],
      packages: [SentryPackage('name', 'version')],
    );
