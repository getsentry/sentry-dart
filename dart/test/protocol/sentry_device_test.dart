import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  final testBootTime = DateTime.fromMicrosecondsSinceEpoch(0);

  final sentryDevice = SentryDevice(
    name: 'testDevice',
    family: 'testFamily',
    model: 'testModel',
    modelId: 'testModelId',
    arch: 'testArch',
    batteryLevel: 23.0,
    orientation: SentryOrientation.landscape,
    manufacturer: 'testOEM',
    brand: 'testBrand',
    screenResolution: '123x345',
    screenDensity: 99.1,
    screenDpi: 100,
    online: false,
    charging: true,
    lowMemory: false,
    simulator: true,
    memorySize: 1234567,
    freeMemory: 12345,
    usableMemory: 9876,
    storageSize: 1234567,
    freeStorage: 1234567,
    externalStorageSize: 98765,
    externalFreeStorage: 98765,
    bootTime: testBootTime,
    timezone: 'Australia/Melbourne',
  );

  final sentryDeviceJson = <String, dynamic>{
    'name': 'testDevice',
    'family': 'testFamily',
    'model': 'testModel',
    'model_id': 'testModelId',
    'arch': 'testArch',
    'battery_level': 23.0,
    'orientation': 'landscape',
    'manufacturer': 'testOEM',
    'brand': 'testBrand',
    'screen_resolution': '123x345',
    'screen_density': 99.1,
    'screen_dpi': 100,
    'online': false,
    'charging': true,
    'low_memory': false,
    'simulator': true,
    'memory_size': 1234567,
    'free_memory': 12345,
    'usable_memory': 9876,
    'storage_size': 1234567,
    'free_storage': 1234567,
    'external_storage_size': 98765,
    'external_free_storage': 98765,
    'boot_time': testBootTime.toIso8601String(),
    'timezone': 'Australia/Melbourne',
  };

  group('json', () {
    test('toJson', () {
      final json = sentryDevice.toJson();

      expect(
        MapEquality().equals(sentryDeviceJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryDevice = SentryDevice.fromJson(sentryDeviceJson);
      final json = sentryDevice.toJson();

      expect(
        MapEquality().equals(sentryDeviceJson, json),
        true,
      );
    });
  });
}
