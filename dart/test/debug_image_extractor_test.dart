import 'package:test/test.dart';
import 'package:sentry/src/debug_image_extractor.dart';

import 'mocks/mock_platform.dart';
import 'mocks/mock_platform_checker.dart';
import 'test_utils.dart';

void main() {
  group(DebugImageExtractor, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('returns null for invalid stack trace', () {
      final stackTrace = 'Invalid stack trace';
      final extractor = fixture.getSut(platform: MockPlatform.android());
      final debugImage = extractor.extractFrom(stackTrace);

      expect(debugImage, isNull);
    });

    test('extracts correct debug ID for Android with short debugId', () {
      final stackTrace = '''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 20000000
''';
      final extractor = fixture.getSut(platform: MockPlatform.android());
      final debugImage = extractor.extractFrom(stackTrace);

      expect(
          debugImage?.debugId, equals('89cb80b6-9e0f-123c-a24b-172d050dec73'));
    });

    test('extracts correct debug ID for Android with long debugId', () {
      final stackTrace = '''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'f1c3bcc0279865fe3058404b2831d9e64135386c'
isolate_dso_base: 30000000
''';
      final extractor = fixture.getSut(platform: MockPlatform.android());
      final debugImage = extractor.extractFrom(stackTrace);

      expect(
          debugImage?.debugId, equals('c0bcc3f1-9827-fe65-3058-404b2831d9e6'));
    });

    test('extracts correct debug ID for iOS', () {
      final stackTrace = '''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 30000000
''';
      final extractor = fixture.getSut(platform: MockPlatform.iOS());
      final debugImage = extractor.extractFrom(stackTrace);

      expect(
          debugImage?.debugId, equals('b680cb89-0f9e-3c12-a24b-172d050dec73'));
      expect(debugImage?.codeId, isNull);
    });

    test('sets correct type based on platform', () {
      final stackTrace = '''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 40000000
''';
      final androidExtractor = fixture.getSut(platform: MockPlatform.android());
      final iosExtractor = fixture.getSut(platform: MockPlatform.iOS());

      final androidDebugImage = androidExtractor.extractFrom(stackTrace);
      final iosDebugImage = iosExtractor.extractFrom(stackTrace);

      expect(androidDebugImage?.type, equals('elf'));
      expect(iosDebugImage?.type, equals('macho'));
    });

    test('debug image is null on unsupported platforms', () {
      final stackTrace = '''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 40000000
''';
      final extractor = fixture.getSut(platform: MockPlatform.linux());

      final debugImage = extractor.extractFrom(stackTrace);

      expect(debugImage, isNull);
    });

    test('debugImage is cached after first extraction', () {
      final stackTrace = '''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 10000000
''';
      final extractor = fixture.getSut(platform: MockPlatform.android());

      // First extraction
      final debugImage1 = extractor.extractFrom(stackTrace);
      expect(debugImage1, isNotNull);
      expect(extractor.debugImageForTesting, equals(debugImage1));

      // Second extraction
      final debugImage2 = extractor.extractFrom(stackTrace);
      expect(debugImage2, equals(debugImage1));
    });
  });
}

class Fixture {
  DebugImageExtractor getSut({required MockPlatform platform}) {
    final options = defaultTestOptions(MockPlatformChecker(platform: platform));
    return DebugImageExtractor(options);
  }
}
