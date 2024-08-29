import 'package:test/test.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry/src/debug_image_extractor.dart';

import 'mocks/mock_platform.dart';
import 'mocks/mock_platform_checker.dart';

void main() {
  group('DebugImageExtractor', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('extracts debug image from valid stack trace', () {
      final stackTrace = '''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 10000000
''';
      final extractor = fixture.getSut(platform: MockPlatform.android());
      final debugImage = extractor.extractDebugImageFrom(stackTrace);

      expect(debugImage, isNotNull);
      expect(debugImage?.debugId, isNotEmpty);
      expect(debugImage?.imageAddr, equals('0x10000000'));
    });

    test('returns null for invalid stack trace', () {
      final stackTrace = 'Invalid stack trace';
      final extractor = fixture.getSut(platform: MockPlatform.android());
      final debugImage = extractor.extractDebugImageFrom(stackTrace);

      expect(debugImage, isNull);
    });

    test('extracts correct debug ID for Android', () {
      final stackTrace = '''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 20000000
''';
      final extractor = fixture.getSut(platform: MockPlatform.android());
      final debugImage = extractor.extractDebugImageFrom(stackTrace);

      expect(
          debugImage?.debugId, equals('89cb80b6-9e0f-123c-a24b-172d050dec73'));
    });

    test('extracts correct debug ID for iOS', () {
      final stackTrace = '''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 30000000
''';
      final extractor = fixture.getSut(platform: MockPlatform.iOS());
      final debugImage = extractor.extractDebugImageFrom(stackTrace);

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

      final androidDebugImage =
          androidExtractor.extractDebugImageFrom(stackTrace);
      final iosDebugImage = iosExtractor.extractDebugImageFrom(stackTrace);

      expect(androidDebugImage?.type, equals('elf'));
      expect(iosDebugImage?.type, equals('macho'));
    });
  });
}

class Fixture {
  DebugImageExtractor getSut({required MockPlatform platform}) {
    final options = SentryOptions(dsn: 'https://public@sentry.example.com/1')
      ..platformChecker = MockPlatformChecker(platform: platform);
    return DebugImageExtractor(options);
  }
}
