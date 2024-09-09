import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  group('json', () {
    final fixture = Fixture();

    test('toJson', () {
      final json = fixture.getSentryDeviceObject().toJson();
      final sentryDeviceJson = fixture.getSentryDeviceJson();

      expect(
        MapEquality().equals(sentryDeviceJson['views'][0], json['views'][0]),
        true,
      );

      sentryDeviceJson.remove('views');
      json.remove('views');

      expect(
        MapEquality().equals(sentryDeviceJson, json),
        true,
      );
    });

    test('fromJson', () {
      final sentryDeviceJson = fixture.getSentryDeviceJson();

      final sentryDevice = SentryDevice.fromJson(sentryDeviceJson);
      final json = sentryDevice.toJson();

      expect(
        MapEquality().equals(sentryDeviceJson['views'][0], json['views'][0]),
        true,
      );

      sentryDeviceJson.remove('views');
      json.remove('views');

      expect(
        MapEquality().equals(sentryDeviceJson, json),
        true,
      );
    });

    test('fromJson double screen_height_pixels and screen_width_pixels', () {
      final sentryDeviceJson = fixture.getSentryDeviceJson();
      sentryDeviceJson['views'][0]['screen_height_pixels'] = 100.0;
      sentryDeviceJson['views'][0]['screen_width_pixels'] = 100.0;

      final sentryDevice = SentryDevice.fromJson(sentryDeviceJson);
      final json = sentryDevice.toJson();

      final data = sentryDevice;

      final copy = data.copyWith();

      final dataJson = data.toJson();
      final copyJson = copy.toJson();

      expect(
        MapEquality().equals(dataJson['views'][0], copyJson['views'][0]),
        true,
      );

      dataJson.remove('views');
      copyJson.remove('views');
      sentryDeviceJson.remove('views');
      json.remove('views');

      expect(
        MapEquality().equals(dataJson, copyJson),
        true,
      );

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
    final fixture = Fixture();
    test('copyWith keeps unchanged', () {
      final data = fixture.getSentryDeviceObject();

      final copy = data.copyWith();

      final dataJson = data.toJson();
      final copyJson = copy.toJson();

      expect(
        MapEquality().equals(dataJson['views'][0], copyJson['views'][0]),
        true,
      );

      dataJson.remove('views');
      copyJson.remove('views');

      expect(
        MapEquality().equals(dataJson, copyJson),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = fixture.getSentryDeviceObject();

      final bootTime = DateTime.now();

      final copy = data.copyWith(
        name: 'name1',
        family: 'family1',
        model: 'model1',
        modelId: 'modelId1',
        arch: 'arch1',
        batteryLevel: 2,
        manufacturer: 'manufacturer1',
        brand: 'brand1',
        views: [
          data.views.first.copyWith(
            orientation: SentryOrientation.portrait,
            screenDensity: 99.2,
            screenDpi: 99,
            screenHeightPixels: 2,
            screenWidthPixels: 2,
          )
        ],
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
      );

      expect('name1', copy.name);
      expect('family1', copy.family);
      expect('model1', copy.model);
      expect('modelId1', copy.modelId);
      expect('arch1', copy.arch);
      expect(2, copy.batteryLevel);
      expect('manufacturer1', copy.manufacturer);
      expect('brand1', copy.brand);
      expect(SentryOrientation.portrait, copy.views.first.orientation);
      expect(99.2, copy.views.first.screenDensity);
      expect(99, copy.views.first.screenDpi);
      expect(2, copy.views.first.screenHeightPixels);
      expect(2, copy.views.first.screenWidthPixels);
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
    });
  });
}

class Fixture {
  late final testBootTime = DateTime.fromMicrosecondsSinceEpoch(0);

  Map<String, dynamic> getSentryDeviceJson() {
    var json = <String, dynamic>{
      'name': 'testDevice',
      'family': 'testFamily',
      'model': 'testModel',
      'model_id': 'testModelId',
      'arch': 'testArch',
      'battery_level': 23.0,
      'manufacturer': 'testOEM',
      'brand': 'testBrand',
      'views': [
        {
          'view_id': 0,
          'orientation': 'landscape',
          'screen_density': 99.1,
          'screen_dpi': 100,
          'screen_height_pixels': 100,
          'screen_width_pixels': 100,
        },
      ],
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
    };

    json.addAll(testUnknown);
    return json;
  }

  SentryDevice getSentryDeviceObject() => SentryDevice(
        name: 'testDevice',
        family: 'testFamily',
        model: 'testModel',
        modelId: 'testModelId',
        arch: 'testArch',
        batteryLevel: 23.0,
        manufacturer: 'testOEM',
        brand: 'testBrand',
        views: [
          SentryView(
            0,
            orientation: SentryOrientation.landscape,
            screenDensity: 99.1,
            screenDpi: 100,
            screenHeightPixels: 100,
            screenWidthPixels: 100,
          )
        ],
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
        unknown: testUnknown,
      );
}
