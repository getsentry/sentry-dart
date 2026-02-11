import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('json', () {
    final fixture = Fixture();

    test('toJson', () {
      final json = fixture.getSut().toJson();

      expect(
        DeepCollectionEquality().equals(fixture.sdkVersionJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sdkVersion = SdkVersion.fromJson(fixture.sdkVersionJson);
      final json = sdkVersion.toJson();

      expect(
        DeepCollectionEquality().equals(fixture.sdkVersionJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    final fixture = Fixture();

    test('copyWith keeps unchanged', () {
      final sut = fixture.getSut();
      // ignore: deprecated_member_use_from_same_package
      final copy = sut.copyWith();

      expect(sut.toJson(), copy.toJson());
    });

    test('copyWith takes new values', () {
      final sut = fixture.getSut();

      final packages = [SentryPackage('name1', 'version1')];
      final integrations = ['test1'];
      // ignore: deprecated_member_use_from_same_package
      final copy = sut.copyWith(
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

  group('addPackage', () {
    final fixture = Fixture();

    test('add package if not same name and version', () {
      final sut = fixture.getSut();
      sut.addPackage('name1', 'version1');

      final last = sut.packages.last;
      expect('name1', last.name);
      expect('version1', last.version);
    });
    test('does not add package if the same name and version', () {
      final sut = fixture.getSut();
      sut.addPackage('name', 'version');

      expect(1, sut.packages.length);
    });
  });

  group('addFeature', () {
    final fixture = Fixture();

    test('add feature if not already present', () {
      final sut = fixture.getSut();
      sut.addFeature('newFeature');

      expect(sut.features.last, 'newFeature');
    });

    test('does not add feature if already present', () {
      final sut = fixture.getSut();
      sut.addFeature('testFeature');

      expect(sut.features.where((f) => f == 'testFeature').length, 1);
    });
  });
}

class Fixture {
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
    'features': ['testFeature'],
  };

  Fixture() {
    sdkVersionJson.addAll(testUnknown);
  }

  SdkVersion getSut() => SdkVersion(
        name: 'name',
        version: 'version',
        integrations: ['test'],
        packages: [SentryPackage('name', 'version')],
        features: ['testFeature'],
        unknown: testUnknown,
      );
}
