@TestOn('vm')
library;

import 'dart:io';

import 'package:sentry/src/event_processor/enricher/io_platform_memory.dart';
import 'package:test/test.dart';

import '../../test_utils.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  test('total physical memory', () async {
    final sut = fixture.getSut();
    final totalPhysicalMemory = await sut.getTotalPhysicalMemory();

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
}

class Fixture {
  var options = defaultTestOptions();

  PlatformMemory getSut() {
    return PlatformMemory(options);
  }
}
