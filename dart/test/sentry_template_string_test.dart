import 'package:sentry/src/sentry_template_string.dart';
import 'package:test/test.dart';

void main() {
  final fixture = Fixture();

  group('SentryTemplateString', () {
    test('basic string replacement', () {
      final sut = fixture.getSut("Hello, %s!");
      final result = sut.format(['John']);

      expect(result, 'Hello, John!');
    });

    test('multiple string replacements', () {
      final sut = fixture.getSut("Hello, %s! You are %s years old.");
      final result = sut.format(['John', '25']);

      expect(result, 'Hello, John! You are 25 years old.');
    });

    test('bool argument', () {
      final sut = fixture.getSut("The value is %s");
      final result = sut.format([true]);

      expect(result, 'The value is true');
    });

    test('int argument', () {
      final sut = fixture.getSut("The number is %s");
      final result = sut.format([42]);

      expect(result, 'The number is 42');
    });

    test('double argument', () {
      final sut = fixture.getSut("The decimal is %s");
      final result = sut.format([3.14]);

      expect(result, 'The decimal is 3.14');
    });

    test('mixed argument types', () {
      final sut = fixture.getSut("Name: %s, Age: %s, Active: %s, Score: %s");
      final result = sut.format(['Alice', 30, true, 95.5]);

      expect(result, 'Name: Alice, Age: 30, Active: true, Score: 95.5');
    });

    test('not enough arguments - replace with empty string', () {
      final sut = fixture.getSut("Hello, %s! You are %s years old.");
      final result = sut.format(['John']);

      expect(result, 'Hello, John! You are  years old.');
    });

    test('empty arguments trigger assertion error', () {
      final sut = fixture.getSut("Hello, %s! You are %s years old.");

      expect(() => sut.format([]), throwsA(isA<AssertionError>()));
    });

    test('no placeholder strings trigger assertion error', () {
      final sut = fixture.getSut("Hello, World!");

      expect(() => sut.format(['ignored']), throwsA(isA<AssertionError>()));
    });

    test('too many arguments - ignore extras', () {
      final sut = fixture.getSut("Hello, %s!");
      final result = sut.format(['John', 'extra', 'arguments']);

      expect(result, 'Hello, John!');
    });

    test('unsupported type with toString()', () {
      final sut = fixture.getSut("The object is %s");
      final customObject = CustomObject('test value');
      final result = sut.format([customObject]);

      expect(result, 'The object is CustomObject: test value');
    });

    test('unsupported type with throwing toString() falls back to empty string',
        () {
      final sut = fixture.getSut("The object is %s");
      final result = sut.format([ThrowingToStringObject()]);

      expect(result, 'The object is ');
    });

    test('unsupported type with default toString()', () {
      final sut = fixture.getSut("The object is %s");
      final result = sut.format([NoToStringMethodObject()]);

      expect(result, 'The object is Instance of \'NoToStringMethodObject\'');
    });

    test('template with escaped %%s', () {
      final sut = fixture.getSut("The percentage is %s%%");
      final result = sut.format([50]);

      expect(result, 'The percentage is 50%');
    });

    test('template with literal % character', () {
      final sut = fixture.getSut("The percentage is 50%%, with no extra %s");
      final result = sut.format(['values']);

      expect(result, 'The percentage is 50%, with no extra values');
    });
  });
}

class Fixture {
  SentryTemplateString getSut(String template) {
    return SentryTemplateString(template);
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
