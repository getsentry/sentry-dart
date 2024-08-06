import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  final sentryMessage = SentryMessage(
    'message 1',
    template: 'message %d',
    params: ['1'],
    unknown: testUnknown,
  );

  final sentryMessageJson = <String, dynamic>{
    'formatted': 'message 1',
    'message': 'message %d',
    'params': ['1'],
  };
  sentryMessageJson.addAll(testUnknown);

  group('json', () {
    test('toJson', () {
      final json = sentryMessage.toJson();

      expect(
        DeepCollectionEquality().equals(sentryMessageJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryMessage = SentryMessage.fromJson(sentryMessageJson);
      final json = sentryMessage.toJson();

      expect(
        DeepCollectionEquality().equals(sentryMessageJson, json),
        true,
      );
    });
  });

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryMessage;

      final copy = data.copyWith();

      expect(
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = sentryMessage;

      final copy = data.copyWith(
        formatted: 'message 21',
        template: 'message 2 %d',
        params: ['2'],
      );

      expect('message 21', copy.formatted);
      expect('message 2 %d', copy.template);
      expect(['2'], copy.params);
    });
  });
}
