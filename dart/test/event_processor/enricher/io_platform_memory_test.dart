@TestOn('vm')
library dart_test;

import 'dart:io';

import 'package:sentry/src/event_processor/enricher/io_platform_memory.dart';
import 'package:test/test.dart';

import '../../test_utils.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('total physical memory', () {
    final sut = fixture.getSut();
    final totalPhysicalMemory = sut.getTotalPhysicalMemory();

    switch (Platform.operatingSystem) {
      case 'linux':
        expect(totalPhysicalMemory, isNotNull);
        expect(totalPhysicalMemory! > 0, true);
        break;
      case 'windows':
        expect(totalPhysicalMemory, isNotNull);
        expect(totalPhysicalMemory! > 0, true);
        break;
      default:
        expect(totalPhysicalMemory, isNull);
    }
  });

  test('free physical memory', () {
    final sut = fixture.getSut();
    final freePhysicalMemory = sut.getTotalPhysicalMemory();

    switch (Platform.operatingSystem) {
      case 'linux':
        expect(freePhysicalMemory, isNotNull);
        expect(freePhysicalMemory! > 0, true);
        break;
      case 'windows':
        expect(freePhysicalMemory, isNotNull);
        expect(freePhysicalMemory! > 0, true);
        break;
      default:
        expect(freePhysicalMemory, isNull);
    }
  });
}

class Fixture {
  var options = defaultTestOptions();

  PlatformMemory getSut() {
    return PlatformMemory(options);
  }
}
