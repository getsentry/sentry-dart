import 'package:sentry/src/sentry_template_string.dart';
import 'package:test/test.dart';

void main() {
  final fixture = Fixture();

  group('SentryTemplateString', () {
    test('basic string replacement', () {
      final sut = fixture.getSut("Hello, %s!", ['John']);
      final result = sut.format();

      expect(result, 'Hello, John!');
    });

    test('multiple string replacements', () {
      final sut =
          fixture.getSut("Hello, %s! You are %s years old.", ['John', '25']);
      final result = sut.format();

      expect(result, 'Hello, John! You are 25 years old.');
    });

    test('bool argument', () {
      final sut = fixture.getSut("The value is %s", [true]);
      final result = sut.format();

      expect(result, 'The value is true');
    });

    test('int argument', () {
      final sut = fixture.getSut("The number is %s", [42]);
      final result = sut.format();

      expect(result, 'The number is 42');
    });

    test('double argument', () {
      final sut = fixture.getSut("The decimal is %s", [3.14]);
      final result = sut.format();

      expect(result, 'The decimal is 3.14');
    });

    test('mixed argument types', () {
      final sut = fixture.getSut("Name: %s, Age: %s, Active: %s, Score: %s",
          ['Alice', 30, true, 95.5]);
      final result = sut.format();

      expect(result, 'Name: Alice, Age: 30, Active: true, Score: 95.5');
    });

    test('not enough arguments - replace with empty string', () {
      final sut = fixture.getSut("Hello, %s! You are %s years old.", ['John']);
      final result = sut.format();

      expect(result, 'Hello, John! You are  years old.');
    });

    test('empty arguments trigger assertion error', () {
      final sut = fixture.getSut("Hello, %s! You are %s years old.", []);

      expect(() => sut.format(), throwsA(isA<AssertionError>()));
    });

    test('no placeholder strings trigger assertion error', () {
      final sut = fixture.getSut("Hello, World!", ['ignored']);

      expect(() => sut.format(), throwsA(isA<AssertionError>()));
    });

    test('too many arguments - ignore extras', () {
      final sut = fixture.getSut("Hello, %s!", ['John', 'extra', 'arguments']);
      final result = sut.format();

      expect(result, 'Hello, John!');
    });

    test('unsupported type with toString()', () {
      final sut =
          fixture.getSut("The object is %s", [CustomObject('test value')]);
      final result = sut.format();

      expect(result, 'The object is CustomObject: test value');
    });

    test('unsupported type with throwing toString() falls back to empty string',
        () {
      final sut =
          fixture.getSut("The object is %s", [ThrowingToStringObject()]);
      final result = sut.format();

      expect(result, 'The object is ');
    });

    test('unsupported type with default toString()', () {
      final sut =
          fixture.getSut("The object is %s", [NoToStringMethodObject()]);
      final result = sut.format();

      expect(result, 'The object is Instance of \'NoToStringMethodObject\'');
    });

    test('template with escaped %%s', () {
      final sut = fixture.getSut("The percentage is %s%%", [50]);
      final result = sut.format();

      expect(result, 'The percentage is 50%');
    });

    test('template with literal % character', () {
      final sut = fixture
          .getSut("The percentage is 50%%, with no extra %s", ['values']);
      final result = sut.format();

      expect(result, 'The percentage is 50%, with no extra values');
    });

    test('toString() prints formatted string', () {
      final sut = fixture.getSut("Hello, %s!", ['John']);
      final result = sut.toString();

      expect(result, 'Hello, John!');
    });
  });
}

class Fixture {
  SentryTemplateString getSut(String template, List<dynamic> arguments) {
    return SentryTemplateString(template, arguments);
  }
}

class CustomObject {
  final String value;

  CustomObject(this.value);

  @override
  String toString() {
    return 'CustomObject: $value';
  }
}

class ThrowingToStringObject {
  @override
  String toString() {
    throw Exception('toString() is broken');
  }
}

class NoToStringMethodObject {
  var foo = "bar";
}
