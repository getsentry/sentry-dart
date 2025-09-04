import 'package:test/test.dart';
import 'package:sentry/sentry.dart';

void main() {
  group('MaxRequestBodySize', () {
    test('getSizeLimit returns correct values', () {
      expect(MaxRequestBodySize.never.getSizeLimit(), equals(0));
      expect(MaxRequestBodySize.small.getSizeLimit(), equals(4000));
      expect(MaxRequestBodySize.medium.getSizeLimit(), equals(10000));
      expect(MaxRequestBodySize.always.getSizeLimit(), isNull);
    });

    test('shouldAddBody works correctly with getSizeLimit', () {
      // never - should never add body
      expect(MaxRequestBodySize.never.shouldAddBody(0), isFalse);
      expect(MaxRequestBodySize.never.shouldAddBody(1000), isFalse);
      expect(MaxRequestBodySize.never.shouldAddBody(10000), isFalse);

      // small - should add body up to 4000 bytes
      expect(MaxRequestBodySize.small.shouldAddBody(0), isTrue);
      expect(MaxRequestBodySize.small.shouldAddBody(4000), isTrue);
      expect(MaxRequestBodySize.small.shouldAddBody(4001), isFalse);
      expect(MaxRequestBodySize.small.shouldAddBody(10000), isFalse);

      // medium - should add body up to 10000 bytes
      expect(MaxRequestBodySize.medium.shouldAddBody(0), isTrue);
      expect(MaxRequestBodySize.medium.shouldAddBody(4000), isTrue);
      expect(MaxRequestBodySize.medium.shouldAddBody(10000), isTrue);
      expect(MaxRequestBodySize.medium.shouldAddBody(10001), isFalse);

      // always - should always add body
      expect(MaxRequestBodySize.always.shouldAddBody(0), isTrue);
      expect(MaxRequestBodySize.always.shouldAddBody(1000), isTrue);
      expect(MaxRequestBodySize.always.shouldAddBody(10000), isTrue);
      expect(MaxRequestBodySize.always.shouldAddBody(100000), isTrue);
    });
  });

  group('MaxResponseBodySize', () {
    test('getSizeLimit returns correct values', () {
      expect(MaxResponseBodySize.never.getSizeLimit(), equals(0));
      expect(MaxResponseBodySize.small.getSizeLimit(), equals(4000));
      expect(MaxResponseBodySize.medium.getSizeLimit(), equals(10000));
      expect(MaxResponseBodySize.always.getSizeLimit(), isNull);
    });

    test('shouldAddBody works correctly with getSizeLimit', () {
      // never - should never add body
      expect(MaxResponseBodySize.never.shouldAddBody(0), isFalse);
      expect(MaxResponseBodySize.never.shouldAddBody(1000), isFalse);
      expect(MaxResponseBodySize.never.shouldAddBody(10000), isFalse);

      // small - should add body up to 4000 bytes
      expect(MaxResponseBodySize.small.shouldAddBody(0), isTrue);
      expect(MaxResponseBodySize.small.shouldAddBody(4000), isTrue);
      expect(MaxResponseBodySize.small.shouldAddBody(4001), isFalse);
      expect(MaxResponseBodySize.small.shouldAddBody(10000), isFalse);

      // medium - should add body up to 10000 bytes
      expect(MaxResponseBodySize.medium.shouldAddBody(0), isTrue);
      expect(MaxResponseBodySize.medium.shouldAddBody(4000), isTrue);
      expect(MaxResponseBodySize.medium.shouldAddBody(10000), isTrue);
      expect(MaxResponseBodySize.medium.shouldAddBody(10001), isFalse);

      // always - should always add body
      expect(MaxResponseBodySize.always.shouldAddBody(0), isTrue);
      expect(MaxResponseBodySize.always.shouldAddBody(1000), isTrue);
      expect(MaxResponseBodySize.always.shouldAddBody(10000), isTrue);
      expect(MaxResponseBodySize.always.shouldAddBody(100000), isTrue);
    });
  });
}
