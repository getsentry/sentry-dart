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

    test('orientation handles portrait', () {
      final map = {'orientation': 'portrait'};
      final sentryDevice = SentryDevice.fromJson(map);
      expect(sentryDevice.orientation, SentryOrientation.portrait);
    });

    test('orientation handles landscape', () {
      final map = {'orientation': 'landscape'};
      final sentryDevice = SentryDevice.fromJson(map);
      expect(sentryDevice.orientation, SentryOrientation.landscape);
    });

    test('orientation returns null for invalid enum value', () {
      final map = {'orientation': 'invalid'};
      final sentryDevice = SentryDevice.fromJson(map);
      expect(sentryDevice.orientation, isNull);
    });

    test('orientation returns null for non-string value', () {
      final map = {'orientation': 123};
      final sentryDevice = SentryDevice.fromJson(map);
      expect(sentryDevice.orientation, isNull);
    });

    test('bootTime parses valid ISO8601 string', () {
      final dateTime = DateTime(2023, 10, 15, 12, 30, 45);
      final map = {'boot_time': dateTime.toIso8601String()};
      final sentryDevice = SentryDevice.fromJson(map);
      expect(sentryDevice.bootTime, isNotNull);
      expect(sentryDevice.bootTime!.year, 2023);
      expect(sentryDevice.bootTime!.month, 10);
      expect(sentryDevice.bootTime!.day, 15);
    });

    test('bootTime returns null for invalid date string', () {
      final map = {'boot_time': 'not a date'};
      final sentryDevice = SentryDevice.fromJson(map);
      expect(sentryDevice.bootTime, isNull);
    });

    test('bootTime returns null for non-string value', () {
      final map = {'boot_time': 12345};
      final sentryDevice = SentryDevice.fromJson(map);
      expect(sentryDevice.bootTime, isNull);
    });

    test('string fields return null for non-string values', () {
      final map = {
        'name': 123,
        'family': true,
        'model': ['array'],
        'arch': {'object': 'value'},
      };
      final sentryDevice = SentryDevice.fromJson(map);
      expect(sentryDevice.name, isNull);
      expect(sentryDevice.family, isNull);
      expect(sentryDevice.model, isNull);
      expect(sentryDevice.arch, isNull);
    });

    test('int fields return null for non-numeric values', () {
      final map = {
        'screen_height_pixels': 'not a number',
        'screen_width_pixels': true,
        'screen_dpi': ['array'],
        'processor_count': {'object': 'value'},
      };
      final sentryDevice = SentryDevice.fromJson(map);
      expect(sentryDevice.screenHeightPixels, isNull);
      expect(sentryDevice.screenWidthPixels, isNull);
      expect(sentryDevice.screenDpi, isNull);
      expect(sentryDevice.processorCount, isNull);
    });

    test('double fields return null for non-numeric values', () {
      final map = {
        'screen_density': 'not a number',
        'processor_frequency': true,
      };
      final sentryDevice = SentryDevice.fromJson(map);
      expect(sentryDevice.screenDensity, isNull);
      expect(sentryDevice.processorFrequency, isNull);
    });

    test('bool fields return null for non-boolean values', () {
      final map = {
        'online': 'true',
        'simulator': 'false',
      };
      final sentryDevice = SentryDevice.fromJson(map);
      expect(sentryDevice.online, isNull);
      expect(sentryDevice.simulator, isNull);
    });

    test('bool fields accept numeric 0 and 1 as false and true', () {
      final map = {
        'charging': 1,
        'low_memory': 0,
        'online': 1.0,
        'simulator': 0.0,
      };
      final sentryDevice = SentryDevice.fromJson(map);
      expect(sentryDevice.charging, true);
      expect(sentryDevice.lowMemory, false);
      expect(sentryDevice.online, true);
      expect(sentryDevice.simulator, false);
    });

    test('bool fields return null for other numeric values', () {
      final map = {
        'charging': 2,
        'low_memory': -1,
        'online': 0.5,
      };
      final sentryDevice = SentryDevice.fromJson(map);
      expect(sentryDevice.charging, isNull);
      expect(sentryDevice.lowMemory, isNull);
      expect(sentryDevice.online, isNull);
    });

    test('mixed valid and invalid data deserializes partially', () {
      final map = {
        'name': 'valid name',
        'family': 123, // invalid
        'battery_level': 75.5,
        'orientation': 'invalid', // invalid enum
        'online': true,
        'charging': 'not a bool', // invalid
        'screen_height_pixels': 1920,
        'screen_width_pixels': 'not a number', // invalid
        'boot_time': 'not a date', // invalid
      };
      final sentryDevice = SentryDevice.fromJson(map);

      // Valid fields should deserialize correctly
      expect(sentryDevice.name, 'valid name');
      expect(sentryDevice.batteryLevel, 75.5);
      expect(sentryDevice.online, true);
      expect(sentryDevice.screenHeightPixels, 1920);

      // Invalid fields should be null
      expect(sentryDevice.family, isNull);
      expect(sentryDevice.orientation, isNull);
      expect(sentryDevice.charging, isNull);
      expect(sentryDevice.screenWidthPixels, isNull);
      expect(sentryDevice.bootTime, isNull);
    });
  });

  test('copyWith keeps unchanged', () {
    final data = _generate();
    // ignore: deprecated_member_use_from_same_package
    final copy = data.copyWith();

    expect(
      MapEquality().equals(data.toJson(), copy.toJson()),
      true,
    );
  });

  test('copyWith takes new values', () {
    final data = _generate();

    final bootTime = DateTime.now();
    // ignore: deprecated_member_use_from_same_package
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
      screenHeightPixels: 900,
      screenWidthPixels: 700,
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
    expect(900, copy.screenHeightPixels);
    expect(700, copy.screenWidthPixels);
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
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryDevice;
      // ignore: deprecated_member_use_from_same_package
      final copy = data.copyWith();

      expect(
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = sentryDevice;

      final bootTime = DateTime.now();
      // ignore: deprecated_member_use_from_same_package
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

SentryDevice _generate({DateTime? testBootTime}) => SentryDevice(
      name: 'name',
      family: 'family',
      model: 'model',
      modelId: 'modelId',
      arch: 'arch',
      batteryLevel: 1,
      orientation: SentryOrientation.landscape,
      manufacturer: 'manufacturer',
      brand: 'brand',
      screenHeightPixels: 600,
      screenWidthPixels: 800,
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
      bootTime: testBootTime ?? DateTime.now(),
    );
