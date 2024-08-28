import 'package:test/test.dart';
import 'package:sentry/sentry.dart';

import 'mocks.dart';
import 'mocks/mock_platform.dart';
import 'mocks/mock_platform_checker.dart';

void main() {
  late DebugImageExtractor symbolizer;
  late SentryOptions options;
  late MockPlatformChecker mockPlatformChecker;

  setUp(() {
    options = SentryOptions(dsn: fakeDsn);
    symbolizer = DebugImageExtractor(options);
  });

  test('Symbolizer correctly parses a valid stack trace header on Android', () {
    mockPlatformChecker = MockPlatformChecker(platform: MockPlatform.android());
    options.platformChecker = mockPlatformChecker;

    final validStackTrace = StackTrace.fromString('''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
os: android, arch: arm64, comp: yes, sim: no
build_id: 'f1c3bcc0279865fe3058404b2831d9e64135386c'
isolate_dso_base: 0f00000000
''');

    final debugImage = symbolizer.toImage(validStackTrace)!;

    expect(debugImage.type, equals('elf'));
    expect(debugImage.imageAddr, equals('0x0f00000000'));
    expect(
        debugImage.codeId, equals('f1c3bcc0279865fe3058404b2831d9e64135386c'));
    expect(debugImage.debugId, equals('c0bcc3f1-9827-fe65-3058-404b2831d9e6'));
  });

  test('Symbolizer correctly parses a valid stack trace header on iOS', () {
    mockPlatformChecker = MockPlatformChecker(platform: MockPlatform.iOS());
    options.platformChecker = mockPlatformChecker;

    final validStackTrace = StackTrace.fromString('''
*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
os: ios, arch: arm64, comp: yes, sim: no
build_id: 'b680cb890f9e3c12a24b172d050dec73'
isolate_dso_base: 0f00000000
''');
    expect(debugImage.type, equals('macho'));
    expect(debugImage.imageAddr, equals('0x0f00000000'));
    // expect(
    // debugImage.codeId, equals('f1c3bcc0279865fe3058404b2831d9e64135386c'));
    expect(debugImage.debugId, equals('c0bcc3f1-9827-fe65-3058-404b2831d9e6'));
  });
}
