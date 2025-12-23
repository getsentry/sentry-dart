import 'package:sentry/sentry.dart';
import 'package:sentry/src/utils/debug_logger.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group(SentryDebugLogger, () {
    tearDown(() {
      // Reset to default state after each test
      SentryDebugLogger.configure(isEnabled: false);
    });

    group('configuration', () {
      test('enables logging when isEnabled is true', () {
        SentryDebugLogger.configure(isEnabled: true);

        expect(SentryDebugLogger.isEnabled, isTrue);
      });

      test('disables logging when isEnabled is false', () {
        SentryDebugLogger.configure(isEnabled: false);

        expect(SentryDebugLogger.isEnabled, isFalse);
      });

      test('sets minimum level', () {
        SentryDebugLogger.configure(
          isEnabled: true,
          minLevel: SentryLevel.error,
        );

        expect(SentryDebugLogger.isEnabled, isTrue);
        expect(SentryDebugLogger.minLevel, equals(SentryLevel.error));
      });

      test('defaults minLevel to warning', () {
        SentryDebugLogger.configure(isEnabled: true);

        expect(SentryDebugLogger.minLevel, equals(SentryLevel.warning));
      });

      test('SentryOptions.debug enables logger', () {
        final options = defaultTestOptions();

        expect(options.debug, isFalse);
        options.debug = true;

        expect(SentryDebugLogger.isEnabled, isTrue);
      });

      test('SentryOptions.diagnosticLevel sets minLevel', () {
        final options = defaultTestOptions();

        options.diagnosticLevel = SentryLevel.error;
        options.debug = true;

        expect(SentryDebugLogger.isEnabled, isTrue);
        expect(SentryDebugLogger.minLevel, equals(SentryLevel.error));
      });
    });

    group('logging when enabled', () {
      setUp(() {
        SentryDebugLogger.configure(
            isEnabled: true, minLevel: SentryLevel.debug);
      });

      test('debug logs without throwing', () {
        expect(
          () => debugLogger.debug('debug message'),
          returnsNormally,
        );
      });

      test('info logs without throwing', () {
        expect(
          () => debugLogger.info('info message'),
          returnsNormally,
        );
      });

      test('warning logs without throwing', () {
        expect(
          () => debugLogger.warning('warning message'),
          returnsNormally,
        );
      });

      test('error logs without throwing', () {
        expect(
          () => debugLogger.error('error message'),
          returnsNormally,
        );
      });

      test('fatal logs without throwing', () {
        expect(
          () => debugLogger.fatal('fatal message'),
          returnsNormally,
        );
      });

      test('accepts error object', () {
        expect(
          () => debugLogger.error(
            'error occurred',
            error: Exception('test exception'),
          ),
          returnsNormally,
        );
      });

      test('accepts stackTrace', () {
        expect(
          () => debugLogger.error(
            'error occurred',
            error: Exception('test'),
            stackTrace: StackTrace.current,
          ),
          returnsNormally,
        );
      });
    });

    group('logger instances', () {
      test('debugLogger constant is available', () {
        expect(debugLogger, isA<SentryDebugLogger>());
      });

      test('can create logger with custom name', () {
        const customLogger = SentryDebugLogger('sentry.flutter');

        SentryDebugLogger.configure(isEnabled: true);

        expect(
          () => customLogger.info('test from flutter logger'),
          returnsNormally,
        );
      });
    });
  });
}
