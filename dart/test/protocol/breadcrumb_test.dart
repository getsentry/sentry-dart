import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';
import 'package:sentry/src/utils.dart';

void main() {
  final timestamp = DateTime.now();

  final breadcrumb = Breadcrumb(
    message: 'message',
    timestamp: timestamp,
    data: {'key': 'value'},
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
}
