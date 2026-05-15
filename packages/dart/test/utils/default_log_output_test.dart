@TestOn('vm')
library;

import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/utils/_io_default_log_output.dart' as io_log;
import 'package:test/test.dart';

void main() {
  group('defaultLogOutput (IO)', () {
    // The IO implementation routes to `dart:developer.log`, not `print`,
    // so it must never appear via the zone's `print` hook. This is the
    // same property we rely on for the web implementation, which forwards
    // to `console.*` directly instead of `print` — see #3043 and the
    // accompanying note in `_web_default_log_output.dart` about avoiding
    // Sentry's print-breadcrumb integration.
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

    test('does not throw for any SentryLevel', () {
      for (final level in const [
        SentryLevel.fatal,
        SentryLevel.error,
        SentryLevel.warning,
        SentryLevel.info,
        SentryLevel.debug,
      ]) {
        expect(
          () => io_log.defaultLogOutput(
            name: 'sentry_dart',
            level: level,
            message: 'msg',
            error: StateError('e'),
            stackTrace: StackTrace.current,
          ),
          returnsNormally,
          reason: 'defaultLogOutput must accept all SentryLevels',
        );
      }
    });
  });
}
