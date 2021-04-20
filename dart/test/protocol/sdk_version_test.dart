import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  final sdkVersion = SdkVersion(
    name: 'name',
    version: 'version',
    integrations: ['test'],
    packages: [SentryPackage('name', 'version')],
  );

  final sdkVersionJson = <String, dynamic>{
    'name': 'name',
    'version': 'version',
    'integrations': ['test'],
    'packages': [
      {
        'name': 'name',
        'version': 'version',
      }
    ],
  };

  group('json', () {
    test('toJson', () {
      final json = sdkVersion.toJson();

      expect(
        DeepCollectionEquality().equals(sdkVersionJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sdkVersion = SdkVersion.fromJson(sdkVersionJson);
      final json = sdkVersion.toJson();

      expect(
        DeepCollectionEquality().equals(sdkVersionJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sdkVersion;

      final copy = data.copyWith();

      expect(data.toJson(), copy.toJson());
    });

    test('copyWith takes new values', () {
      final data = sdkVersion;

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
  });
}
