import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  
  final sentryGpu = SentryGpu(
    name: 'fixture-name',
    id: 1,
    vendorId: 2,
    vendorName: 'fixture-vendorName',
    memorySize: 3,
    apiType: 'fixture-apiType',
    multiThreadedRendering: true,
    version: '4',
    npotSupport: 'fixture-npotSupport'
  );

  final sentryGpuJson = <String, dynamic>{
    'name': 'fixture-name',
    'id': 1,
    'vendor_id': 2,
    'vendor_name': 'fixture-vendorName',
    'memory_size': 3,
    'api_type': 'fixture-apiType',
    'multi_threaded_rendering': true,
    'version': '4',
    'npot_support': 'fixture-npotSupport'
  };

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
}
