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

  group('copyWith', () {
    test('copyWith keeps unchanged', () {
      final data = sentryBrowser;
      // ignore: deprecated_member_use_from_same_package
      final copy = data.copyWith();

      expect(
        MapEquality().equals(data.toJson(), copy.toJson()),
        true,
      );
    });

    test('copyWith takes new values', () {
      final data = sentryBrowser;
      // ignore: deprecated_member_use_from_same_package
      final copy = data.copyWith(
        name: 'name1',
        version: 'version1',
      );

      expect('name1', copy.name);
      expect('version1', copy.version);
    });
  });
}
