@TestOn('vm')
library;

import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/utils/_io_default_log_output.dart' as io_log;
import 'package:sentry/src/utils/_web_default_log_output.dart' as web_log;
import 'package:test/test.dart';

void main() {
  group('defaultLogOutput (IO)', () {
    // The IO implementation routes to `dart:developer.log`, not `print`,
    // so it should never produce stdout output via `print`.
    test('does not forward the message to print', () {
      final captured = <String>[];

      runZoned(
        () {
          io_log.defaultLogOutput(
            name: 'sentry_dart',
            level: SentryLevel.warning,
            message: 'hello world',
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => captured.add(line),
        ),
      );

      expect(captured, isEmpty);
    });
  });

  group('defaultLogOutput (Web)', () {
    test('forwards the message to print with name and level prefix', () {
      final captured = <String>[];

      runZoned(
        () {
          web_log.defaultLogOutput(
            name: 'sentry_dart',
            level: SentryLevel.warning,
            message: 'hello world',
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => captured.add(line),
        ),
      );

      expect(captured, hasLength(1));
      expect(captured.first, '[sentry_dart] [warning] hello world');
    });

    test('appends error and stack trace when provided', () {
      final captured = <String>[];
      final error = StateError('boom');
      final stackTrace = StackTrace.current;

      runZoned(
        () {
          web_log.defaultLogOutput(
            name: 'sentry_flutter',
            level: SentryLevel.error,
            message: 'failed to do something',
            error: error,
            stackTrace: stackTrace,
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => captured.add(line),
        ),
      );

      expect(captured, hasLength(1));
      final output = captured.first;
      expect(output,
          startsWith('[sentry_flutter] [error] failed to do something'));
      expect(output, contains('\n  error: Bad state: boom'));
      expect(output, contains('\n  stack: '));
    });

    test('does not append empty error/stack lines when null', () {
      final captured = <String>[];

      runZoned(
        () {
          web_log.defaultLogOutput(
            name: 'sentry_dart',
            level: SentryLevel.info,
            message: 'plain message',
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => captured.add(line),
        ),
      );

      expect(captured, hasLength(1));
      final output = captured.first;
      expect(output, '[sentry_dart] [info] plain message');
      expect(output, isNot(contains('error:')));
      expect(output, isNot(contains('stack:')));
    });
  });
}
