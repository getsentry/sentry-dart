import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final mechanism = Mechanism(
    type: 'type',
    description: 'description',
    helpLink: 'helpLink',
    handled: true,
    synthetic: true,
    meta: {'key': 'value'},
    data: {'keyb': 'valueb'},
    isExceptionGroup: false,
    exceptionId: 0,
    parentId: 0,
    source: 'source',
    unknown: testUnknown,
  );

  final mechanismJson = <String, dynamic>{
    'type': 'type',
    'description': 'description',
    'help_link': 'helpLink',
    'handled': true,
    'meta': {'key': 'value'},
    'data': {'keyb': 'valueb'},
    'synthetic': true,
    'is_exception_group': false,
    'source': 'source',
    'exception_id': 0,
    'parent_id': 0,
  };
  mechanismJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = mechanism.toJson();

      expect(
        DeepCollectionEquality().equals(mechanismJson, json),
        true,
      );
    });
    test('fromJson', () {
      final mechanism = Mechanism.fromJson(mechanismJson);
      final json = mechanism.toJson();

      expect(
        DeepCollectionEquality().equals(mechanismJson, json),
        true,
      );
    });
  });
}
