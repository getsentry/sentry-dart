import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith keeps unchanged', () {
    final data = _generate();

    final copy = data.copyWith();

    expect(
      MapEquality().equals(data.toJson(), copy.toJson()),
      true,
    );
  });

  test('copyWith takes new values', () {
    final data = _generate();

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
