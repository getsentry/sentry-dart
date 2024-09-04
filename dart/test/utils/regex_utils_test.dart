import 'package:sentry/src/utils/regex_utils.dart';
import 'package:test/test.dart';

void main() {
  group('regex_utils', () {
    final testString = "this is a test";

    test('testString contains string pattern', () {
      expect(isMatchingRegexPattern(testString, ["is"]), isTrue);
    });

    test('testString does not contain string pattern', () {
      expect(isMatchingRegexPattern(testString, ["not"]), isFalse);
    });

    test('testString contains regex pattern', () {
      expect(isMatchingRegexPattern(testString, ["^this.*\$"]), isTrue);
    });

    test('testString does not contain regex pattern', () {
      expect(isMatchingRegexPattern(testString, ["^is.*\$"]), isFalse);
    });
  });
}
