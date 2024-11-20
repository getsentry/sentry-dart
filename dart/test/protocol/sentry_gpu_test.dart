import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final sentryGpu = SentryGpu(
    name: 'fixture-name',
    id: 1,
    vendorId: '2',
    vendorName: 'fixture-vendorName',
    memorySize: 3,
    apiType: 'fixture-apiType',
    multiThreadedRendering: true,
    version: '4',
    npotSupport: 'fixture-npotSupport',
    unknown: testUnknown,
  );

  final sentryGpuJson = <String, dynamic>{
    'name': 'fixture-name',
    'id': 1,
    'vendor_id': '2',
    'vendor_name': 'fixture-vendorName',
    'memory_size': 3,
    'api_type': 'fixture-apiType',
    'multi_threaded_rendering': true,
    'version': '4',
    'npot_support': 'fixture-npotSupport'
  };
  sentryGpuJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = sentryGpu.toJson();

      expect(
        MapEquality().equals(sentryGpuJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryGpu = SentryGpu.fromJson(sentryGpuJson);
      final json = sentryGpu.toJson();

      expect(
        MapEquality().equals(sentryGpuJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryGpu;

      final copy = data.copyWith();

      expect(
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });
    test('copyWith takes new values', () {
      final data = sentryGpu;

      final copy = data.copyWith(
        name: 'name1',
        id: 11,
        vendorId: '22',
        vendorName: 'vendorName1',
        memorySize: 33,
        apiType: 'apiType1',
        multiThreadedRendering: false,
        version: 'version1',
        npotSupport: 'npotSupport1',
      );

      expect('name1', copy.name);
      expect(11, copy.id);
      expect('22', copy.vendorId);
      expect('vendorName1', copy.vendorName);
      expect(33, copy.memorySize);
      expect('apiType1', copy.apiType);
      expect(false, copy.multiThreadedRendering);
      expect('version1', copy.version);
      expect('npotSupport1', copy.npotSupport);
    });
  });
}
