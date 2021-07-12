import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';
import 'package:sentry/src/utils.dart';

void main() {
  final timestamp = DateTime.now();

  final breadcrumb = Breadcrumb(
    message: 'message',
    timestamp: timestamp,
    data: <String, Object>{'key': 'value'},
    level: SentryLevel.warning,
    category: 'category',
    type: 'type',
  );

  final breadcrumbJson = <String, dynamic>{
    'timestamp': formatDateAsIso8601WithMillisPrecision(timestamp),
    'message': 'message',
    'category': 'category',
    'data': {'key': 'value'},
    'level': 'warning',
    'type': 'type',
  };

  group('json', () {
    test('toJson', () {
      final json = breadcrumb.toJson();

      expect(
        DeepCollectionEquality().equals(breadcrumbJson, json),
        true,
      );
    });

    test('fromJson', () {
      final breadcrumb = Breadcrumb.fromJson(breadcrumbJson);
      final json = breadcrumb.toJson();

      expect(
        DeepCollectionEquality().equals(breadcrumbJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = breadcrumb;

      final copy = data.copyWith();

      expect(
        MapEquality<String, dynamic>().equals(data.toJson(), copy.toJson()),
        true,
      );
    });
    test('copyWith takes new values', () {
      final data = breadcrumb;

      final timestamp = DateTime.now();

      final copy = data.copyWith(
        message: 'message1',
        timestamp: timestamp,
        data: <String, Object>{'key1': 'value1'},
        level: SentryLevel.fatal,
        category: 'category1',
        type: 'type1',
      );

      expect('message1', copy.message);
      expect(timestamp, copy.timestamp);
      expect(<String, Object>{'key1': 'value1'}, copy.data);
      expect(SentryLevel.fatal, copy.level);
      expect('category1', copy.category);
      expect('type1', copy.type);
    });
  });

  test('Breadcrumb http ctor', () {
    final breadcrumb = Breadcrumb.http(
      url: Uri.parse('https://example.org'),
      method: 'GET',
      level: SentryLevel.fatal,
      reason: 'OK',
      statusCode: 200,
      requestDuration: Duration.zero,
      timestamp: DateTime.now(),
    );
    final json = breadcrumb.toJson();

    expect(json, {
      'timestamp': formatDateAsIso8601WithMillisPrecision(breadcrumb.timestamp),
      'category': 'http',
      'data': {
        'url': 'https://example.org',
        'method': 'GET',
        'status_code': 200,
        'reason': 'OK',
        'duration': '0:00:00.000000'
      },
      'level': 'fatal',
      'type': 'http',
    });
  });
}
