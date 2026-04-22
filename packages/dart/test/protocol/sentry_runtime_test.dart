import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final sentryRuntime = SentryRuntime(
    key: 'key',
    name: 'name',
    version: 'version',
    rawDescription: 'rawDescription',
    unknown: testUnknown,
  );

  final sentryRuntimeJson = <String, dynamic>{
    'name': 'name',
    'version': 'version',
    'raw_description': 'rawDescription',
  };
  sentryRuntimeJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = sentryRuntime.toJson();

      expect(
        MapEquality().equals(sentryRuntimeJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryRuntime = SentryRuntime.fromJson(sentryRuntimeJson);
      final json = sentryRuntime.toJson();

      expect(
        MapEquality().equals(sentryRuntimeJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryRuntime;
      // ignore: deprecated_member_use_from_same_package
      final copy = data.copyWith();

      expect(
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = sentryRuntime;
      // ignore: deprecated_member_use_from_same_package
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
  });

  group('toAttributes', () {
    test('returns empty map when name, version, and rawDescription are null',
        () {
      expect(SentryRuntime(compiler: 'dart2js').toAttributes(), isEmpty);
    });

    test('maps name, version, and rawDescription to process.runtime.* keys',
        () {
      final runtime = SentryRuntime(
        name: 'Dart',
        version: '3.5.0',
        rawDescription: 'Dart VM 3.5.0 (stable)',
      );

      final attributes = runtime.toAttributes();

      expect(attributes[SemanticAttributesConstants.processRuntimeName]?.value,
          'Dart');
      expect(attributes[SemanticAttributesConstants.processRuntimeName]?.type,
          'string');
      expect(
          attributes[SemanticAttributesConstants.processRuntimeVersion]?.value,
          '3.5.0');
      expect(
          attributes[SemanticAttributesConstants.processRuntimeDescription]
              ?.value,
          'Dart VM 3.5.0 (stable)');
    });

    test('does not include compiler or build without stable semantic keys', () {
      final runtime = SentryRuntime(
        name: 'Dart',
        compiler: 'dart2js',
        build: '3.5.0.1',
      );

      final attributes = runtime.toAttributes();

      expect(attributes.keys,
          unorderedEquals([SemanticAttributesConstants.processRuntimeName]));
    });
  });
}
