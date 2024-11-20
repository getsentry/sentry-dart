import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

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
    batteryStatus: 'Unknown',
    cpuDescription: 'M1 Pro Max Ultra',
    deviceType: 'Flutter Device',
    deviceUniqueIdentifier: 'uuid',
    processorCount: 4,
    processorFrequency: 1.2,
    supportsAccelerometer: true,
    supportsGyroscope: true,
    supportsAudio: true,
    supportsLocationService: true,
    supportsVibration: true,
    screenHeightPixels: 100,
    screenWidthPixels: 100,
    unknown: testUnknown,
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
    'battery_status': 'Unknown',
    'cpu_description': 'M1 Pro Max Ultra',
    'device_type': 'Flutter Device',
    'device_unique_identifier': 'uuid',
    'processor_count': 4,
    'processor_frequency': 1.2,
    'supports_accelerometer': true,
    'supports_gyroscope': true,
    'supports_audio': true,
    'supports_location_service': true,
    'supports_vibration': true,
    'screen_height_pixels': 100,
    'screen_width_pixels': 100,
  };
  sentryDeviceJson.addAll(testUnknown);

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

    test('fromJson double screen_height_pixels and screen_width_pixels', () {
      sentryDeviceJson['screen_height_pixels'] = 100.0;
      sentryDeviceJson['screen_width_pixels'] = 100.0;

      final sentryDevice = SentryDevice.fromJson(sentryDeviceJson);
      final json = sentryDevice.toJson();

      expect(
        MapEquality().equals(sentryDeviceJson, json),
        true,
      );
    });

    test('batery level converts int to double', () {
      final map = {'battery_level': 1};

      final sentryDevice = SentryDevice.fromJson(map);

      expect(
        sentryDevice.batteryLevel,
        1.0,
      );
    });

    test('batery level maps double', () {
      final map = {'battery_level': 1.0};

      final sentryDevice = SentryDevice.fromJson(map);

      expect(
        sentryDevice.batteryLevel,
        1.0,
      );
    });

    test('batery level ignores if not a num', () {
      final map = {'battery_level': 'abc'};

      final sentryDevice = SentryDevice.fromJson(map);

      expect(
        sentryDevice.batteryLevel,
        null,
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
        batteryStatus: 'Charging',
        cpuDescription: 'Intel i9',
        deviceType: 'Tablet',
        deviceUniqueIdentifier: 'foo_bar_baz',
        processorCount: 8,
        processorFrequency: 3.4,
        supportsAccelerometer: false,
        supportsGyroscope: false,
        supportsAudio: false,
        supportsLocationService: false,
        supportsVibration: false,
        screenHeightPixels: 2,
        screenWidthPixels: 2,
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
      expect('Charging', copy.batteryStatus);
      expect('Intel i9', copy.cpuDescription);
      expect('Tablet', copy.deviceType);
      expect('foo_bar_baz', copy.deviceUniqueIdentifier);
      expect(8, copy.processorCount);
      expect(3.4, copy.processorFrequency);
      expect(false, copy.supportsAccelerometer);
      expect(false, copy.supportsGyroscope);
      expect(false, copy.supportsAudio);
      expect(false, copy.supportsLocationService);
      expect(false, copy.supportsVibration);
      expect(2, copy.screenHeightPixels);
      expect(2, copy.screenWidthPixels);
    });
  });
}
