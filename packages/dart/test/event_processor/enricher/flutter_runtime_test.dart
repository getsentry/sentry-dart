import 'package:sentry/src/event_processor/enricher/flutter_runtime.dart';
import 'package:test/test.dart';

void main() {
  group('FlutterVersionComponents', () {
    test('stores major and minor correctly', () {
      const components = FlutterVersionComponents(3, 33);
      expect(components.major, 3);
      expect(components.minor, 33);
    });

    test('equality works correctly', () {
      const a = FlutterVersionComponents(3, 33);
      const b = FlutterVersionComponents(3, 33);
      const c = FlutterVersionComponents(3, 32);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = FlutterVersionComponents(3, 33);
      const b = FlutterVersionComponents(3, 33);

      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString returns readable format', () {
      const components = FlutterVersionComponents(3, 33);
      expect(components.toString(), 'FlutterVersionComponents(3, 33)');
    });

    group('meetsMinimum', () {
      test('returns false when major is less than threshold', () {
        expect(
            const FlutterVersionComponents(2, 99).meetsMinimum(3, 0), isFalse);
        expect(
            const FlutterVersionComponents(2, 0).meetsMinimum(3, 33), isFalse);
      });

      test('returns false when major equals but minor is less than threshold',
          () {
        expect(
            const FlutterVersionComponents(3, 32).meetsMinimum(3, 33), isFalse);
        expect(
            const FlutterVersionComponents(3, 0).meetsMinimum(3, 33), isFalse);
      });

      test('returns true when major equals and minor equals threshold', () {
        expect(
            const FlutterVersionComponents(3, 33).meetsMinimum(3, 33), isTrue);
        expect(const FlutterVersionComponents(4, 0).meetsMinimum(4, 0), isTrue);
      });

      test('returns true when major equals and minor exceeds threshold', () {
        expect(
            const FlutterVersionComponents(3, 34).meetsMinimum(3, 33), isTrue);
        expect(
            const FlutterVersionComponents(3, 99).meetsMinimum(3, 33), isTrue);
      });

      test('returns true when major exceeds threshold', () {
        expect(
            const FlutterVersionComponents(4, 0).meetsMinimum(3, 33), isTrue);
        expect(
            const FlutterVersionComponents(5, 0).meetsMinimum(3, 99), isTrue);
        expect(
            const FlutterVersionComponents(10, 0).meetsMinimum(3, 33), isTrue);
      });

      test('works with various threshold values', () {
        // Testing different thresholds
        expect(const FlutterVersionComponents(2, 5).meetsMinimum(2, 5), isTrue);
        expect(
            const FlutterVersionComponents(2, 4).meetsMinimum(2, 5), isFalse);
        expect(const FlutterVersionComponents(1, 0).meetsMinimum(1, 0), isTrue);
        expect(
            const FlutterVersionComponents(0, 0).meetsMinimum(0, 1), isFalse);
      });
    });
  });

  group('FlutterVersion.parseVersion', () {
    test('parses standard version format (major.minor.patch)', () {
      final result = FlutterVersion.parseComponents('3.33.0');
      expect(result, isNotNull);
      expect(result!.major, 3);
      expect(result.minor, 33);
    });

    test('parses version with pre-release suffix', () {
      final result = FlutterVersion.parseComponents('3.33.0-pre.123');
      expect(result, isNotNull);
      expect(result!.major, 3);
      expect(result.minor, 33);
    });

    test('parses version with build metadata', () {
      final result = FlutterVersion.parseComponents('3.33.0+hotfix.1');
      expect(result, isNotNull);
      expect(result!.major, 3);
      expect(result.minor, 33);
    });

    test('parses major.minor only (no patch)', () {
      final result = FlutterVersion.parseComponents('4.0');
      expect(result, isNotNull);
      expect(result!.major, 4);
      expect(result.minor, 0);
    });

    test('parses version with large numbers', () {
      final result = FlutterVersion.parseComponents('10.100.999');
      expect(result, isNotNull);
      expect(result!.major, 10);
      expect(result.minor, 100);
    });

    test('returns null for single number (no dot)', () {
      expect(FlutterVersion.parseComponents('3'), isNull);
    });

    test('returns null for non-numeric major', () {
      expect(FlutterVersion.parseComponents('abc.33.0'), isNull);
    });

    test('returns null for non-numeric minor', () {
      expect(FlutterVersion.parseComponents('3.abc.0'), isNull);
    });

    test('returns null for empty string', () {
      expect(FlutterVersion.parseComponents(''), isNull);
    });

    test('returns null for dot only', () {
      expect(FlutterVersion.parseComponents('.'), isNull);
    });

    test('returns null for leading dot', () {
      expect(FlutterVersion.parseComponents('.33.0'), isNull);
    });

    test('returns null for minor with hyphen suffix without patch', () {
      // "3.33-beta" -> "33-beta" is not a valid integer
      expect(FlutterVersion.parseComponents('3.33-beta'), isNull);
    });

    test('parses version where minor ends at patch separator', () {
      // "3.33.0-beta" -> major=3, minor=33
      final result = FlutterVersion.parseComponents('3.33.0-beta');
      expect(result, isNotNull);
      expect(result!.major, 3);
      expect(result.minor, 33);
    });

    test('handles version 0.0.0', () {
      final result = FlutterVersion.parseComponents('0.0.0');
      expect(result, isNotNull);
      expect(result!.major, 0);
      expect(result.minor, 0);
    });

    test('returns null for malformed version', () {
      expect(FlutterVersion.parseComponents('invalid'), isNull);
    });
  });
}
