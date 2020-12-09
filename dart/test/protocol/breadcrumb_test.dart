import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  test('copyWith keeps unchanged', () {
    final breadcrumb = _getBreadcrumb();

    final copy = breadcrumb.copyWith();

    expect(
      MapEquality().equals(breadcrumb.toJson(), copy.toJson()),
      true,
    );
  });

  test('copyWith takes new values', () {
    final breadcrumb = _getBreadcrumb();

    final timestamp = DateTime.now();

    final copy = breadcrumb.copyWith(
        message: 'message1',
        timestamp: timestamp,
        data: {'key1': 'value1'},
        level: SentryLevel.fatal,
        category: 'category1',
        type: 'type1');

    expect('message1', copy.message);
    expect(timestamp, copy.timestamp);
    expect({'key1': 'value1'}, copy.data);
    expect(SentryLevel.fatal, copy.level);
    expect('category1', copy.category);
    expect('type1', copy.type);
  });
}

Breadcrumb _getBreadcrumb({DateTime timestamp}) => Breadcrumb(
    message: 'message',
    timestamp: timestamp ?? DateTime.now(),
    data: {'key': 'value'},
    level: SentryLevel.warning,
    category: 'category',
    type: 'type');
