// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group(Contexts, () {
    final testBootTime = DateTime.fromMicrosecondsSinceEpoch(0);

    final testDevice = SentryDevice(
      name: 'testDevice',
      family: 'testFamily',
      model: 'testModel',
      modelId: 'testModelId',
      arch: 'testArch',
      batteryLevel: 23,
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
    );
    const testOS = SentryOperatingSystem(name: 'testOS');
    final testRuntimes = [
      const SentryRuntime(name: 'testRT1', version: '1.0'),
      const SentryRuntime(name: 'testRT2', version: '2.3.1'),
    ];
    const testApp = SentryApp(version: '1.2.3');
    const testBrowser = SentryBrowser(version: '12.3.4');

    final gpu = SentryGpu(name: 'Radeon', version: '1');

    final contexts = Contexts(
      device: testDevice,
      operatingSystem: testOS,
      runtimes: testRuntimes,
      app: testApp,
      browser: testBrowser,
      gpu: gpu,
    )
      ..['theme'] = {'value': 'material'}
      ..['version'] = {'value': 9};

    final contextsJson = <String, dynamic>{
      'device': {
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
      },
      'os': {
        'name': 'testOS',
      },
      'app': {'app_version': '1.2.3'},
      'browser': {'version': '12.3.4'},
      'gpu': {'name': 'Radeon', 'version': '1'},
      'testrt1': {'name': 'testRT1', 'type': 'runtime', 'version': '1.0'},
      'testrt2': {'name': 'testRT2', 'type': 'runtime', 'version': '2.3.1'},
      'theme': {'value': 'material'},
      'version': {'value': 9},
    };

    test('serializes to JSON', () {
      final event = SentryEvent(contexts: contexts);

      expect(event.toJson()['contexts'], contextsJson);
    });

    test('deserializes/serializes JSON', () {
      final contexts = Contexts.fromJson(contextsJson);
      final json = contexts.toJson();

      expect(
        DeepCollectionEquality().equals(contextsJson, json),
        true,
      );
    });

    test('clone context', () {
      final clone = contexts.clone();

      expect(clone.app!.toJson(), contexts.app!.toJson());
      expect(clone.browser!.toJson(), contexts.browser!.toJson());
      expect(clone.device!.toJson(), contexts.device!.toJson());
      expect(
          clone.operatingSystem!.toJson(), contexts.operatingSystem!.toJson());
      expect(clone.gpu!.toJson(), contexts.gpu!.toJson());

      for (final element in contexts.runtimes) {
        expect(
          clone.runtimes.where(
            (clone) => MapEquality().equals(element.toJson(), clone.toJson()),
          ),
          isNotEmpty,
        );
      }

      expect(clone['theme'], {'value': 'material'});
      expect(clone['version'], {'value': 9});
    });
  });

  group('parse contexts', () {
    test('should parse json context', () {
      final contexts = Contexts.fromJson(jsonDecode(jsonContexts));
      expect(
        MapEquality().equals(
          contexts.operatingSystem!.toJson(),
          {
            'build': '19H2',
            'rooted': false,
            'kernel_version':
                'Darwin Kernel Version 19.6.0: Mon Aug 31 22:12:52 PDT 2020; root:xnu-6153.141.2~1/RELEASE_X86_64',
            'name': 'iOS',
            'version': '14.2'
          },
        ),
        true,
      );
      expect(
        MapEquality().equals(contexts.device!.toJson(), {
          'simulator': true,
          'model_id': 'simulator',
          'arch': 'x86',
          'free_memory': 232132608,
          'family': 'iOS',
          'model': 'iPhone13,4',
          'memory_size': 17179869184,
          'storage_size': 1023683072000,
          'boot_time': '2020-11-18T13:28:11.000Z',
          'usable_memory': 17114120192
        }),
        true,
      );

      expect(
        MapEquality().equals(
          contexts.app!.toJson(),
          {
            'app_id': 'D533244D-985D-3996-9FC2-9FA353D28586',
            'app_name': 'sentry_flutter_example',
            'app_version': '0.1.2',
            'app_identifier': 'io.sentry.flutter.example',
            'app_start_time': '2020-11-18T13:56:58.000Z',
            'device_app_hash': '59ca66aa7ac0bdc3d82f77041643036f6323bd6d',
            'app_build': '3',
            'build_type': 'simulator',
          },
        ),
        true,
      );
      expect(
        MapEquality().equals(contexts.runtimes.first.toJson(), {
          'name': 'testRT1',
          'version': '1.0',
          'raw_description': 'runtime description RT1 1.0'
        }),
        true,
      );
      expect(
        MapEquality().equals(contexts.browser!.toJson(), {'version': '12.3.4'}),
        true,
      );
      expect(
        MapEquality()
            .equals(contexts.gpu!.toJson(), {'name': 'Radeon', 'version': '1'}),
        true,
      );
    });
  });
}

const jsonContexts = '''
{
  "os": {
    "build": "19H2",
    "rooted": false,
    "kernel_version": "Darwin Kernel Version 19.6.0: Mon Aug 31 22:12:52 PDT 2020; root:xnu-6153.141.2~1/RELEASE_X86_64",
    "name": "iOS",
    "version": "14.2"
  },
  "device": {
    "simulator": true,
    "model_id": "simulator",
    "arch": "x86",
    "free_memory": 232132608,
    "family": "iOS",
    "model": "iPhone13,4",
    "memory_size": 17179869184,
    "storage_size": 1023683072000,
    "boot_time": "2020-11-18T13:28:11Z",
    "usable_memory": 17114120192
  },
  "app": {
    "app_id": "D533244D-985D-3996-9FC2-9FA353D28586",
    "app_version": "0.1.2",
    "app_identifier": "io.sentry.flutter.example",
    "app_start_time": "2020-11-18T13:56:58Z",
    "device_app_hash": "59ca66aa7ac0bdc3d82f77041643036f6323bd6d",
    "app_build": "3",
    "build_type": "simulator",
    "app_name": "sentry_flutter_example"
  },
  "runtime":
   {
      "name":"testRT1",
      "version":"1.0",
      "raw_description":"runtime description RT1 1.0"
   },
   "browser": {"version": "12.3.4"},
   "gpu": {"name": "Radeon", "version": "1"}
  
}
''';
