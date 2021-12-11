import 'package:logging/logging.dart';
import 'package:sentry_logging/src/extension.dart';
import 'package:test/test.dart';

void main() {
  test('breadcrumb time is always utc', () {
    final log = LogRecord(Level.CONFIG, 'foo bar', 'test logger');

    expect(log.toBreadcrumb().timestamp.isUtc, true);
  });

  test('event time is always utc', () {
    final log = LogRecord(Level.CONFIG, 'foo bar', 'test logger');

    expect(log.toEvent().timestamp?.isUtc, true);
  });
}
