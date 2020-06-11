// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group(Contexts, () {
    final testBootTime = DateTime.fromMicrosecondsSinceEpoch(0);
    test('serializes to JSON', () {
      final testDevice = Device(
        name: 'testDevice',
        family: 'testFamily',
        model: 'testModel',
        modelId: 'testModelId',
        arch: 'testArch',
        batteryLevel: 23,
        orientation: Orientation.landscape,
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
      final testOS = OperatingSystem(name: 'testOS');
      final testRuntimes = [
        Runtime(name: 'testRT1', version: '1.0'),
        Runtime(name: 'testRT2', version: '2.3.1'),
      ];
      final testApp = App(version: '1.2.3');
      final testBrowser = Browser(version: '12.3.4');

      final contexts = Contexts(
        device: testDevice,
        operatingSystem: testOS,
        runtimes: testRuntimes,
        app: testApp,
        browser: testBrowser,
      );

      final event = Event(contexts: contexts);

      expect(
        event.toJson()['contexts'],
        <String, dynamic>{
          'device': {
            'name': 'testDevice',
            'family': 'testFamily',
            'model': 'testModel',
            'model_id': 'testModelId',
            'arch': 'testArch',
            'battery_level': 23,
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
          },
          'os': {
            'name': 'testOS',
          },
          'testrt1': {'name': 'testRT1', 'type': 'runtime', 'version': '1.0'},
          'testrt2': {'name': 'testRT2', 'type': 'runtime', 'version': '2.3.1'},
          'app': {'app_version': '1.2.3'},
          'browser': {'version': '12.3.4'},
        },
      );
    });
  });
}
