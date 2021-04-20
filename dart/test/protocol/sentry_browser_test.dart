import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  
  final sentryBrowser = SentryBrowser(
    name: 'fixture-name',
    version: 'fixture-version',
  );

  final sentryBrowserJson = <String, dynamic>{
    'name': 'fixture-name',
    'version': 'fixture-version',
  };

  group('json', () {
    test('toJson', () {
      final json = sentryBrowser.toJson();

      expect(
        MapEquality().equals(sentryBrowserJson, json),
        true,
      );
    });
    test('fromJson', () {
      final sentryBrowser = SentryBrowser.fromJson(sentryBrowserJson);
      final json = sentryBrowser.toJson();

      expect(
        MapEquality().equals(sentryBrowserJson, json),
        true,
      );
    });
  });
}
