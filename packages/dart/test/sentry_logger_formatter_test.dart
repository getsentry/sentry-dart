import 'package:test/test.dart';
import 'package:sentry/src/sentry_logger_formatter.dart';
import 'package:sentry/src/sentry_logger.dart';
import 'package:sentry/src/protocol/sentry_attribute.dart';

void main() {
  final fixture = Fixture();

  void verifyPassedAttributes(Map<String, dynamic> attributes) {
    expect(attributes['foo'].type, 'string');
    expect(attributes['foo'].value, 'bar');
  }

  void verifyBasicTemplate(String body, Map<String, dynamic> attributes) {
    expect(body, 'Hello, World!');
    expect(attributes['sentry.message.template'].type, 'string');
    expect(attributes['sentry.message.template'].value, 'Hello, %s!');
    expect(attributes['sentry.message.parameter.0'].type, 'string');
    expect(attributes['sentry.message.parameter.0'].value, 'World');
    verifyPassedAttributes(attributes);
  }

  void verifyTemplateWithMultipleArguments(
      String body, Map<String, dynamic> attributes) {
    expect(body, 'Name: Alice, Age: 30, Active: true, Score: 95.5');
    expect(attributes['sentry.message.template'].type, 'string');
    expect(attributes['sentry.message.template'].value,
        'Name: %s, Age: %s, Active: %s, Score: %s');
    expect(attributes['sentry.message.parameter.0'].type, 'string');
    expect(attributes['sentry.message.parameter.0'].value, 'Alice');
    expect(attributes['sentry.message.parameter.1'].type, 'integer');
    expect(attributes['sentry.message.parameter.1'].value, 30);
    expect(attributes['sentry.message.parameter.2'].type, 'boolean');
    expect(attributes['sentry.message.parameter.2'].value, true);
    expect(attributes['sentry.message.parameter.3'].type, 'double');
    expect(attributes['sentry.message.parameter.3'].value, 95.5);
    verifyPassedAttributes(attributes);
  }

  group('format basic template', () {
    test('for trace', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.trace(
        "Hello, %s!",
        ["World"],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.traceCalls.length, 1);
      final message = logger.traceCalls[0].message;
      final attributes = logger.traceCalls[0].attributes!;
      verifyBasicTemplate(message, attributes);
    });

    test('for debug', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.debug(
        "Hello, %s!",
        ["World"],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.debugCalls.length, 1);
      final message = logger.debugCalls[0].message;
      final attributes = logger.debugCalls[0].attributes!;
      verifyBasicTemplate(message, attributes);
    });

    test('for info', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.info(
        "Hello, %s!",
        ["World"],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.infoCalls.length, 1);
      final message = logger.infoCalls[0].message;
      final attributes = logger.infoCalls[0].attributes!;
      verifyBasicTemplate(message, attributes);
    });

    test('for warn', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.warn(
        "Hello, %s!",
        ["World"],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.warnCalls.length, 1);
      final message = logger.warnCalls[0].message;
      final attributes = logger.warnCalls[0].attributes!;
      verifyBasicTemplate(message, attributes);
    });

    test('for error', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.error(
        "Hello, %s!",
        ["World"],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.errorCalls.length, 1);
      final message = logger.errorCalls[0].message;
      final attributes = logger.errorCalls[0].attributes!;
      verifyBasicTemplate(message, attributes);
    });

    test('for fatal', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.fatal(
        "Hello, %s!",
        ["World"],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.fatalCalls.length, 1);
      final message = logger.fatalCalls[0].message;
      final attributes = logger.fatalCalls[0].attributes!;
      verifyBasicTemplate(message, attributes);
    });
  });

  group('template with multiple arguments', () {
    test('for trace', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.trace(
        "Name: %s, Age: %s, Active: %s, Score: %s",
        ['Alice', 30, true, 95.5],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.traceCalls.length, 1);
      final message = logger.traceCalls[0].message;
      final attributes = logger.traceCalls[0].attributes!;
      verifyTemplateWithMultipleArguments(message, attributes);
    });

    test('for trace', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.trace(
        "Name: %s, Age: %s, Active: %s, Score: %s",
        ['Alice', 30, true, 95.5],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.traceCalls.length, 1);
      final message = logger.traceCalls[0].message;
      final attributes = logger.traceCalls[0].attributes!;
      verifyTemplateWithMultipleArguments(message, attributes);
    });

    test('for debug', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.debug(
        "Name: %s, Age: %s, Active: %s, Score: %s",
        ['Alice', 30, true, 95.5],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.debugCalls.length, 1);
      final message = logger.debugCalls[0].message;
      final attributes = logger.debugCalls[0].attributes!;
      verifyTemplateWithMultipleArguments(message, attributes);
    });

    test('for info', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.info(
        "Name: %s, Age: %s, Active: %s, Score: %s",
        ['Alice', 30, true, 95.5],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.infoCalls.length, 1);
      final message = logger.infoCalls[0].message;
      final attributes = logger.infoCalls[0].attributes!;
      verifyTemplateWithMultipleArguments(message, attributes);
    });

    test('for warn', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.warn(
        "Name: %s, Age: %s, Active: %s, Score: %s",
        ['Alice', 30, true, 95.5],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.warnCalls.length, 1);
      final message = logger.warnCalls[0].message;
      final attributes = logger.warnCalls[0].attributes!;
      verifyTemplateWithMultipleArguments(message, attributes);
    });

    test('for error', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.error(
        "Name: %s, Age: %s, Active: %s, Score: %s",
        ['Alice', 30, true, 95.5],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.errorCalls.length, 1);
      final message = logger.errorCalls[0].message;
      final attributes = logger.errorCalls[0].attributes!;
      verifyTemplateWithMultipleArguments(message, attributes);
    });

    test('for fatal', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.fatal(
        "Name: %s, Age: %s, Active: %s, Score: %s",
        ['Alice', 30, true, 95.5],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.fatalCalls.length, 1);
      final message = logger.fatalCalls[0].message;
      final attributes = logger.fatalCalls[0].attributes!;
      verifyTemplateWithMultipleArguments(message, attributes);
    });
  });

  group('template with no arguments', () {
    test('for trace', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.trace(
        "Hello, World!",
        [],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.traceCalls.length, 1);
      final message = logger.traceCalls[0].message;
      final attributes = logger.traceCalls[0].attributes!;

      expect(message, 'Hello, World!');
      expect(attributes['sentry.message.template'], isNull);
      expect(attributes['sentry.message.parameter.0'], isNull);
      verifyPassedAttributes(attributes);
    });

    test('for debug', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.debug(
        "Hello, World!",
        [],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.debugCalls.length, 1);
      final message = logger.debugCalls[0].message;
      final attributes = logger.debugCalls[0].attributes!;

      expect(message, 'Hello, World!');
      expect(attributes['sentry.message.template'], isNull);
      expect(attributes['sentry.message.parameter.0'], isNull);
      verifyPassedAttributes(attributes);
    });

    test('for info', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.info(
        "Hello, World!",
        [],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.infoCalls.length, 1);
      final message = logger.infoCalls[0].message;
      final attributes = logger.infoCalls[0].attributes!;

      expect(message, 'Hello, World!');
      expect(attributes['sentry.message.template'], isNull);
      expect(attributes['sentry.message.parameter.0'], isNull);
      verifyPassedAttributes(attributes);
    });

    test('for warn', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.warn(
        "Hello, World!",
        [],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.warnCalls.length, 1);
      final message = logger.warnCalls[0].message;
      final attributes = logger.warnCalls[0].attributes!;

      expect(message, 'Hello, World!');
      expect(attributes['sentry.message.template'], isNull);
      expect(attributes['sentry.message.parameter.0'], isNull);
      verifyPassedAttributes(attributes);
    });

    test('for error', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.error(
        "Hello, World!",
        [],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.errorCalls.length, 1);
      final message = logger.errorCalls[0].message;
      final attributes = logger.errorCalls[0].attributes!;

      expect(message, 'Hello, World!');
      expect(attributes['sentry.message.template'], isNull);
      expect(attributes['sentry.message.parameter.0'], isNull);
      verifyPassedAttributes(attributes);
    });

    test('for fatal', () {
      final logger = MockLogger();
      final sut = fixture.getSut(logger);

      sut.fatal(
        "Hello, World!",
        [],
        attributes: {'foo': SentryAttribute.string('bar')},
      );

      expect(logger.fatalCalls.length, 1);
      final message = logger.fatalCalls[0].message;
      final attributes = logger.fatalCalls[0].attributes!;

      expect(message, 'Hello, World!');
      expect(attributes['sentry.message.template'], isNull);
      expect(attributes['sentry.message.parameter.0'], isNull);
      verifyPassedAttributes(attributes);
    });
  });
}

class Fixture {
  SentryLoggerFormatter getSut(SentryLogger logger) {
    return SentryLoggerFormatter(logger);
  }
}

class MockLogger implements SentryLogger {
  var traceCalls = <LoggerCall>[];
  var debugCalls = <LoggerCall>[];
  var infoCalls = <LoggerCall>[];
  var warnCalls = <LoggerCall>[];
  var errorCalls = <LoggerCall>[];
  var fatalCalls = <LoggerCall>[];

  @override
  SentryLoggerFormatter get fmt => throw UnimplementedError();

  @override
  Future<void> trace(String message, {Map<String, dynamic>? attributes}) async {
    traceCalls.add((message: message, attributes: attributes));
    return;
  }

  @override
  Future<void> debug(String message, {Map<String, dynamic>? attributes}) async {
    debugCalls.add((message: message, attributes: attributes));
    return;
  }

  @override
  Future<void> info(String message, {Map<String, dynamic>? attributes}) async {
    infoCalls.add((message: message, attributes: attributes));
    return;
  }

  @override
  Future<void> warn(String message, {Map<String, dynamic>? attributes}) async {
    warnCalls.add((message: message, attributes: attributes));
    return;
  }

  @override
  Future<void> error(String message, {Map<String, dynamic>? attributes}) async {
    errorCalls.add((message: message, attributes: attributes));
    return;
  }

  @override
  Future<void> fatal(String message, {Map<String, dynamic>? attributes}) async {
    fatalCalls.add((message: message, attributes: attributes));
    return;
  }
}

typedef LoggerCall = ({String message, Map<String, dynamic>? attributes});
