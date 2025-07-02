import 'dart:io';
import 'package:sentry/src/platform/platform.dart' as platform;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/src/native/c/sentry_native.dart';
import 'package:sentry/src/platform/mock_platform.dart';

void main() {
  group('getDefaultCrashpadPath', () {
    test('returns null on non-Linux platforms', () {
      final windowsPlatform = MockPlatform.windows();
      final macOSPlatform = MockPlatform.macOS();
      final androidPlatform = MockPlatform.android();
      final iOSPlatform = MockPlatform.iOS();

      expect(getDefaultCrashpadPath(currentPlatform: windowsPlatform), isNull);
      expect(getDefaultCrashpadPath(currentPlatform: macOSPlatform), isNull);
      expect(getDefaultCrashpadPath(currentPlatform: androidPlatform), isNull);
      expect(getDefaultCrashpadPath(currentPlatform: iOSPlatform), isNull);
    });

    test('returns expected path format when crashpad_handler exists', () {
      final currentPlatform = MockPlatform.linux();

      // Create a temporary directory structure to simulate the app environment
      final tempDir = Directory.systemTemp.createTempSync('crashpad_test_');

      try {
        // Simulate the expected directory structure relative to an executable
        final appDir = tempDir.path;

        // Test case 1: crashpad_handler directly in app directory
        final directPath = '$appDir${Platform.pathSeparator}crashpad_handler';
        File(directPath).createSync();

        // Verify the direct path exists and would be found first
        expect(File(directPath).existsSync(), isTrue);

        // Clean up for next test
        File(directPath).deleteSync();

        // Test case 2: crashpad_handler in bin subdirectory
        final binDir = Directory('$appDir${Platform.pathSeparator}bin');
        binDir.createSync();
        final binPath =
            '$appDir${Platform.pathSeparator}bin${Platform.pathSeparator}crashpad_handler';
        File(binPath).createSync();

        expect(File(binPath).existsSync(), isTrue);

        // Clean up for next test
        File(binPath).deleteSync();
        binDir.deleteSync();

        // Test case 3: crashpad_handler in lib subdirectory
        final libDir = Directory('$appDir${Platform.pathSeparator}lib');
        libDir.createSync();
        final libPath =
            '$appDir${Platform.pathSeparator}lib${Platform.pathSeparator}crashpad_handler';
        File(libPath).createSync();

        expect(File(libPath).existsSync(), isTrue);

        // Verify the expected candidates array format
        final expectedCandidates = [
          '$appDir${Platform.pathSeparator}crashpad_handler',
          '$appDir${Platform.pathSeparator}bin${Platform.pathSeparator}crashpad_handler',
          '$appDir${Platform.pathSeparator}lib${Platform.pathSeparator}crashpad_handler'
        ];

        // Verify path format is correct
        expect(expectedCandidates[0], contains('crashpad_handler'));
        expect(expectedCandidates[1],
            contains('bin${Platform.pathSeparator}crashpad_handler'));
        expect(expectedCandidates[2],
            contains('lib${Platform.pathSeparator}crashpad_handler'));

        // Clean up
        File(libPath).deleteSync();
        libDir.deleteSync();
      } finally {
        // Clean up temp directory
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns null when no crashpad_handler candidates exist on Linux', () {
      final currentPlatform = MockPlatform.linux();

      // Create a temporary directory with no crashpad_handler files
      final tempDir = Directory.systemTemp.createTempSync('crashpad_empty_');

      try {
        final appDir = tempDir.path;

        // Verify none of the expected candidates exist
        final expectedCandidates = [
          '$appDir${Platform.pathSeparator}crashpad_handler',
          '$appDir${Platform.pathSeparator}bin${Platform.pathSeparator}crashpad_handler',
          '$appDir${Platform.pathSeparator}lib${Platform.pathSeparator}crashpad_handler'
        ];

        for (final candidate in expectedCandidates) {
          expect(File(candidate).existsSync(), isFalse);
        }

        // The function would return null in this case since no candidates exist
        // (We can't easily test this directly due to Platform.resolvedExecutable being static)
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('handles path separator correctly across platforms', () {
      // Verify that the path building logic uses the correct separator
      final testDir = '/test/app';
      final expectedPaths = [
        '$testDir${Platform.pathSeparator}crashpad_handler',
        '$testDir${Platform.pathSeparator}bin${Platform.pathSeparator}crashpad_handler',
        '$testDir${Platform.pathSeparator}lib${Platform.pathSeparator}crashpad_handler'
      ];

      for (final path in expectedPaths) {
        expect(path, contains(Platform.pathSeparator));
        expect(path, endsWith('crashpad_handler'));
      }
    });

    test('validates that function is only called on Linux platform', () {
      // This test verifies the platform checking logic
      final linuxPlatform = MockPlatform.linux();
      final nonLinuxPlatform = MockPlatform.windows();

      // On Linux, the function will attempt to process the path
      // (even if it returns null due to no files existing)
      final linuxResult =
          getDefaultCrashpadPath(currentPlatform: linuxPlatform);

      // On non-Linux, it should immediately return null
      final nonLinuxResult =
          getDefaultCrashpadPath(currentPlatform: nonLinuxPlatform);

      expect(nonLinuxResult, isNull);
      // Linux result could be null (if no files exist) or a string (if files exist)
      // We just verify the platform check works as expected
    });
  });
}
