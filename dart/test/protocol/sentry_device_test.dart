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

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryDevice;

      final copy = data.copyWith();

      expect(
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = sentryDevice;

      final bootTime = DateTime.now();

      final copy = data.copyWith(
        name: 'name1',
        family: 'family1',
        model: 'model1',
        modelId: 'modelId1',
        arch: 'arch1',
        batteryLevel: 2,
        orientation: SentryOrientation.portrait,
        manufacturer: 'manufacturer1',
        brand: 'brand1',
        screenResolution: '123x3451',
        screenDensity: 99.2,
        screenDpi: 99,
        online: true,
        charging: false,
        lowMemory: true,
        simulator: false,
        memorySize: 12345678,
        freeMemory: 123456,
        usableMemory: 98765,
        storageSize: 12345678,
        freeStorage: 12345678,
        externalStorageSize: 987654,
        externalFreeStorage: 987654,
        bootTime: bootTime,
        timezone: 'Austria/Vienna',
      );

      expect('name1', copy.name);
      expect('family1', copy.family);
      expect('model1', copy.model);
      expect('modelId1', copy.modelId);
      expect('arch1', copy.arch);
      expect(2, copy.batteryLevel);
      expect(SentryOrientation.portrait, copy.orientation);
      expect('manufacturer1', copy.manufacturer);
      expect('brand1', copy.brand);
      expect('123x3451', copy.screenResolution);
      expect(99.2, copy.screenDensity);
      expect(99, copy.screenDpi);
      expect(true, copy.online);
      expect(false, copy.charging);
      expect(true, copy.lowMemory);
      expect(false, copy.simulator);
      expect(12345678, copy.memorySize);
      expect(123456, copy.freeMemory);
      expect(98765, copy.usableMemory);
      expect(12345678, copy.storageSize);
      expect(12345678, copy.freeStorage);
      expect(987654, copy.externalStorageSize);
      expect(987654, copy.externalFreeStorage);
      expect(bootTime, copy.bootTime);
      expect('Austria/Vienna', copy.timezone);
    });
  });
}
