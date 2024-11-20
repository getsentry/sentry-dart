import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final timestamp = DateTime.now();

  final breadcrumb = Breadcrumb(
    message: 'message',
    timestamp: timestamp,
    data: {'key': 'value'},
    level: SentryLevel.warning,
    category: 'category',
    type: 'type',
    unknown: testUnknown,
  );

  final breadcrumbJson = <String, dynamic>{
    'timestamp': formatDateAsIso8601WithMillisPrecision(timestamp),
    'message': 'message',
    'category': 'category',
    'data': {'key': 'value'},
    'level': 'warning',
    'type': 'type',
  };
  breadcrumbJson.addAll(testUnknown);

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
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });
    test('copyWith takes new values', () {
      final data = breadcrumb;

      final timestamp = DateTime.now();

      final copy = data.copyWith(
        message: 'message1',
        timestamp: timestamp,
        data: {'key1': 'value1'},
        level: SentryLevel.fatal,
        category: 'category1',
        type: 'type1',
      );

      expect('message1', copy.message);
      expect(timestamp, copy.timestamp);
      expect({'key1': 'value1'}, copy.data);
      expect(SentryLevel.fatal, copy.level);
      expect('category1', copy.category);
      expect('type1', copy.type);
    });
  });

  group('ctor', () {
    test('Breadcrumb http', () {
      final breadcrumb = Breadcrumb.http(
          url: Uri.parse('https://example.org'),
          method: 'GET',
          level: SentryLevel.fatal,
          reason: 'OK',
          statusCode: 200,
          requestDuration: Duration(milliseconds: 55),
          timestamp: DateTime.now(),
          requestBodySize: 2,
          responseBodySize: 3,
          httpQuery: 'foo=bar',
          httpFragment: 'baz');
      final json = breadcrumb.toJson();

      expect(json, {
        'timestamp':
            formatDateAsIso8601WithMillisPrecision(breadcrumb.timestamp),
        'category': 'http',
        'data': {
          'url': 'https://example.org',
          'method': 'GET',
          'status_code': 200,
          'reason': 'OK',
          'duration': '0:00:00.055000',
          'request_body_size': 2,
          'response_body_size': 3,
          'http.query': 'foo=bar',
          'http.fragment': 'baz',
          'start_timestamp': breadcrumb.timestamp.millisecondsSinceEpoch - 55,
          'end_timestamp': breadcrumb.timestamp.millisecondsSinceEpoch
        },
        'level': 'fatal',
        'type': 'http',
      });
    });

    test('Breadcrumb http', () {
      final breadcrumb = Breadcrumb.http(
        url: Uri.parse('https://example.org'),
        method: 'GET',
        requestDuration: Duration(milliseconds: 10),
      );
      final json = breadcrumb.toJson();

      expect(json, {
        'timestamp':
            formatDateAsIso8601WithMillisPrecision(breadcrumb.timestamp),
        'category': 'http',
        'data': {
          'url': 'https://example.org',
          'method': 'GET',
          'duration': '0:00:00.010000',
          'start_timestamp': breadcrumb.timestamp.millisecondsSinceEpoch - 10,
          'end_timestamp': breadcrumb.timestamp.millisecondsSinceEpoch
        },
        'level': 'info',
        'type': 'http',
      });
    });

    test('Minimal Breadcrumb http', () {
      final breadcrumb = Breadcrumb.http(
        url: Uri.parse('https://example.org'),
        method: 'GET',
      );
      final json = breadcrumb.toJson();

      expect(json, {
        'timestamp':
            formatDateAsIso8601WithMillisPrecision(breadcrumb.timestamp),
        'category': 'http',
        'data': {
          'url': 'https://example.org',
          'method': 'GET',
        },
        'level': 'info',
        'type': 'http',
      });
    });

    test('Breadcrumb console', () {
      final breadcrumb = Breadcrumb.console(
        message: 'Foo Bar',
      );
      final json = breadcrumb.toJson();

      expect(json, {
        'message': 'Foo Bar',
        'timestamp':
            formatDateAsIso8601WithMillisPrecision(breadcrumb.timestamp),
        'category': 'console',
        'type': 'debug',
        'level': 'info',
      });
    });

    test('extensive Breadcrumb console', () {
      final breadcrumb = Breadcrumb.console(
        message: 'Foo Bar',
        level: SentryLevel.error,
        data: {'foo': 'bar'},
      );
      final json = breadcrumb.toJson();

      expect(json, {
        'message': 'Foo Bar',
        'timestamp':
            formatDateAsIso8601WithMillisPrecision(breadcrumb.timestamp),
        'category': 'console',
        'type': 'debug',
        'level': 'error',
        'data': {'foo': 'bar'},
      });
    });

    test('extensive Breadcrumb user interaction', () {
      final time = DateTime.now().toUtc();
      final breadcrumb = Breadcrumb.userInteraction(
        message: 'Foo Bar',
        level: SentryLevel.error,
        timestamp: time,
        data: {'foo': 'bar'},
        subCategory: 'click',
        viewId: 'foo',
        viewClass: 'bar',
      );
      final json = breadcrumb.toJson();

      expect(json, {
        'message': 'Foo Bar',
        'timestamp': formatDateAsIso8601WithMillisPrecision(time),
        'category': 'ui.click',
        'type': 'user',
        'level': 'error',
        'data': {
          'foo': 'bar',
          'view.id': 'foo',
          'view.class': 'bar',
        },
      });
    });
  });
}
