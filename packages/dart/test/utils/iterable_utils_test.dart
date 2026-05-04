import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('SentryIterableUtils', () {
    group('firstOrNull', () {
      test('returns null for an empty iterable', () {
        expect(SentryIterableUtils.firstOrNull(<int>[]), isNull);
      });

      test('returns the first item', () {
        expect(SentryIterableUtils.firstOrNull([1, 2, 3]), 1);
      });
    });

    group('firstWhereOrNull', () {
      test('returns null when no item matches', () {
        expect(
          SentryIterableUtils.firstWhereOrNull(
            [1, 3, 5],
            (item) => item.isEven,
          ),
          isNull,
        );
      });

      test('returns the first matching item', () {
        expect(
          SentryIterableUtils.firstWhereOrNull(
            [1, 2, 4],
            (item) => item.isEven,
          ),
          2,
        );
      });
    });
  });
}
