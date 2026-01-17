import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

import '../mocks.dart';

void main() {
  late Fixture fixture;

  setUp(() {
    fixture = Fixture();
  });

  group('SentryThread', () {
    test('serializes to json', () {
      final json = fixture.sentryThread.toJson();

      expect(
        DeepCollectionEquality().equals(fixture.sentryThreadJson, json),
        true,
      );
    });

    test('deserializes from json', () {
      final sentryThread = SentryThread.fromJson(fixture.sentryThreadJson);
      final json = sentryThread.toJson();

      expect(
        DeepCollectionEquality().equals(fixture.sentryThreadJson, json),
        true,
      );
    });
  });
}

class Fixture {
  final stackTrace = SentryStackTrace(
    frames: [
      SentryStackFrame(function: 'fixture-function'),
    ],
  );

  late final SentryThread sentryThread = SentryThread(
    id: 1,
    name: 'fixture-thread',
    crashed: true,
    current: false,
    stacktrace: stackTrace,
    unknown: testUnknown,
  );

  late final Map<String, dynamic> sentryThreadJson = () {
    final json = <String, dynamic>{
      'id': 1,
      'name': 'fixture-thread',
      'crashed': true,
      'current': false,
      'stacktrace': stackTrace.toJson(),
    };
    json.addAll(testUnknown);
    return json;
  }();
}
