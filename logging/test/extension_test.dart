import 'package:logging/logging.dart';
import 'package:sentry_logging/src/extension.dart';
import 'package:test/test.dart';

class _TestObject {}

class _TestErrorObject {}

void main() {
  test('breadcrumb time is always utc', () {
    final log = LogRecord(Level.CONFIG, 'foo bar', 'test logger');

    expect(log.toBreadcrumb().timestamp.isUtc, true);
  });

  test('event time is always utc', () {
    final log = LogRecord(Level.CONFIG, 'foo bar', 'test logger');

    expect(log.toEvent().timestamp?.isUtc, true);
  });

  test('user defined objects are converted to string', () {
    // Every value in the data and extra map must be convertible to by the
    // StandardMessageCodec. We convert all user supplied types and the
    // StackTrace to a string to make this property hold.

    final object = _TestObject();
    final error = _TestErrorObject();
    final stackTrace = StackTrace.current;

    final log = LogRecord(
      Level.CONFIG,
      'foo bar',
      'test logger',
      error,
      stackTrace,
      null,
      object,
    );

    final breadcrumb = log.toBreadcrumb();
    expect(
      breadcrumb.data,
      containsPair('LogRecord.object', object.toString()),
    );
    expect(
      log.toBreadcrumb().data,
      containsPair('LogRecord.stackTrace', stackTrace.toString()),
    );

    final event = log.toEvent();
    expect(
      // ignore: deprecated_member_use
      event.extra,
      containsPair('LogRecord.object', object.toString()),
    );
  });
}
