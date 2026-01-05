import 'package:sentry/sentry.dart';
import 'package:sentry/src/utils/internal_logger.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group(SentryInternalLogger, () {
    late List<_CapturedLog> logs;

    LogOutputFunction captureLogOutput() {
      return ({
        required String name,
        required SentryLevel level,
        required String message,
        Object? error,
        StackTrace? stackTrace,
      }) {
        logs.add(_CapturedLog(
          name: name,
          level: level,
          message: message,
          error: error,
          stackTrace: stackTrace,
        ));
      };
    }

    setUp(() {
      logs = [];
    });

    tearDown(() {
      SentryInternalLogger.configure(isEnabled: false);
    });

    group('configuration', () {
      test('enables logging when isEnabled is true', () {
        SentryInternalLogger.configure(isEnabled: true);

        expect(SentryInternalLogger.isEnabled, isTrue);
      });

      test('disables logging when isEnabled is false', () {
        SentryInternalLogger.configure(isEnabled: false);

        expect(SentryInternalLogger.isEnabled, isFalse);
      });

      test('sets minimum level', () {
        SentryInternalLogger.configure(
          isEnabled: true,
          minLevel: SentryLevel.error,
        );

        expect(SentryInternalLogger.isEnabled, isTrue);
        expect(SentryInternalLogger.minLevel, equals(SentryLevel.error));
      });

      test('defaults minLevel to warning', () {
        SentryInternalLogger.configure(isEnabled: true);

        expect(SentryInternalLogger.minLevel, equals(SentryLevel.warning));
      });

      test('SentryOptions.debug enables logger', () {
        final options = defaultTestOptions();

        expect(options.debug, isFalse);
        options.debug = true;

        expect(SentryInternalLogger.isEnabled, isTrue);
      });

      test('SentryOptions.diagnosticLevel sets minLevel when set before debug',
          () {
        final options = defaultTestOptions();

        options.diagnosticLevel = SentryLevel.error;
        options.debug = true;

        expect(SentryInternalLogger.isEnabled, isTrue);
        expect(SentryInternalLogger.minLevel, equals(SentryLevel.error));
      });

      test(
          'SentryOptions.diagnosticLevel updates minLevel when set after debug',
          () {
        final options = defaultTestOptions();

        options.debug = true;
        expect(SentryInternalLogger.minLevel, equals(SentryLevel.warning));

        options.diagnosticLevel = SentryLevel.error;

        expect(SentryInternalLogger.isEnabled, isTrue);
        expect(SentryInternalLogger.minLevel, equals(SentryLevel.error));
      });
    });

    group('logging when enabled', () {
      setUp(() {
        SentryInternalLogger.configure(
          isEnabled: true,
          minLevel: SentryLevel.debug,
          logOutput: captureLogOutput(),
        );
      });

      test('debug logs message with correct level', () {
        internalLogger.debug('debug message');

        expect(logs, hasLength(1));
        expect(logs.first.level, SentryLevel.debug);
        expect(logs.first.message, 'debug message');
        expect(logs.first.name, 'sentry_dart');
      });

      test('info logs message with correct level', () {
        internalLogger.info('info message');

        expect(logs, hasLength(1));
        expect(logs.first.level, SentryLevel.info);
        expect(logs.first.message, 'info message');
      });

      test('warning logs message with correct level', () {
        internalLogger.warning('warning message');

        expect(logs, hasLength(1));
        expect(logs.first.level, SentryLevel.warning);
        expect(logs.first.message, 'warning message');
      });

      test('error logs message with correct level', () {
        internalLogger.error('error message');

        expect(logs, hasLength(1));
        expect(logs.first.level, SentryLevel.error);
        expect(logs.first.message, 'error message');
      });

      test('fatal logs message with correct level', () {
        internalLogger.fatal('fatal message');

        expect(logs, hasLength(1));
        expect(logs.first.level, SentryLevel.fatal);
        expect(logs.first.message, 'fatal message');
      });

      test('includes error object in log entry', () {
        final exception = Exception('test exception');

        internalLogger.error('error occurred', error: exception);

        expect(logs, hasLength(1));
        expect(logs.first.error, exception);
      });

      test('includes stackTrace in log entry', () {
        final stackTrace = StackTrace.current;

        internalLogger.error('error occurred', stackTrace: stackTrace);

        expect(logs, hasLength(1));
        expect(logs.first.stackTrace, stackTrace);
      });
    });

    group('logger instances', () {
      test('debugLogger constant is available', () {
        expect(debugLogger, isA<SentryInternalLogger>());
      });

      test('logs with custom logger name', () {
        const customLogger = SentryInternalLogger('sentry_flutter');
        SentryInternalLogger.configure(
          isEnabled: true,
          logOutput: captureLogOutput(),
        );

        customLogger.warning('test from flutter logger');

        expect(logs, hasLength(1));
        expect(logs.first.name, 'sentry_flutter');
      });
    });

    group('lazy evaluation', () {
      test('does not evaluate function when logging is disabled', () {
        SentryInternalLogger.configure(isEnabled: false);
        var wasCalled = false;

        internalLogger.debug(() {
          wasCalled = true;
          return 'expensive message';
        });

        expect(wasCalled, isFalse);
      });

      test('evaluates function when logging is enabled', () {
        SentryInternalLogger.configure(
          isEnabled: true,
          minLevel: SentryLevel.debug,
        );
        var wasCalled = false;

        internalLogger.debug(() {
          wasCalled = true;
          return 'expensive message';
        });

        expect(wasCalled, isTrue);
      });

      test('does not evaluate function when level is below minLevel', () {
        SentryInternalLogger.configure(
          isEnabled: true,
          minLevel: SentryLevel.warning,
        );
        var wasCalled = false;

        internalLogger.debug(() {
          wasCalled = true;
          return 'debug message';
        });

        expect(wasCalled, isFalse);
      });
    });

    group('level filtering', () {
      test('logs message at minLevel', () {
        SentryInternalLogger.configure(
          isEnabled: true,
          minLevel: SentryLevel.warning,
        );
        var wasCalled = false;

        internalLogger.warning(() {
          wasCalled = true;
          return 'warning message';
        });

        expect(wasCalled, isTrue);
      });

      test('logs message above minLevel', () {
        SentryInternalLogger.configure(
          isEnabled: true,
          minLevel: SentryLevel.warning,
        );
        var wasCalled = false;

        internalLogger.error(() {
          wasCalled = true;
          return 'error message';
        });

        expect(wasCalled, isTrue);
      });

      test('does not log message below minLevel', () {
        SentryInternalLogger.configure(
          isEnabled: true,
          minLevel: SentryLevel.error,
        );
        var wasCalled = false;

        internalLogger.warning(() {
          wasCalled = true;
          return 'warning message';
        });

        expect(wasCalled, isFalse);
      });
    });

    group('message conversion', () {
      setUp(() {
        SentryInternalLogger.configure(
          isEnabled: true,
          minLevel: SentryLevel.debug,
          logOutput: captureLogOutput(),
        );
      });

      test('converts int to string', () {
        internalLogger.info(42);

        expect(logs, hasLength(1));
        expect(logs.first.message, '42');
      });

      test('converts custom object using toString', () {
        internalLogger.info(_TestMessage('custom'));

        expect(logs, hasLength(1));
        expect(logs.first.message, 'TestMessage: custom');
      });

      test('converts list to string', () {
        internalLogger.info([1, 2, 3]);

        expect(logs, hasLength(1));
        expect(logs.first.message, '[1, 2, 3]');
      });

      test('evaluates function and converts result', () {
        internalLogger.info(() => 123);

        expect(logs, hasLength(1));
        expect(logs.first.message, '123');
      });
    });
  });
}

class _CapturedLog {
  final String name;
  final SentryLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  _CapturedLog({
    required this.name,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });
}

class _TestMessage {
  final String value;

  _TestMessage(this.value);

  @override
  String toString() => 'TestMessage: $value';
}
