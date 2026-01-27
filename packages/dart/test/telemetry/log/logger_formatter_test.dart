import 'package:sentry/sentry.dart';
import 'package:sentry/src/telemetry/log/default_logger.dart';
import 'package:test/test.dart';

import '../../test_utils.dart';

void main() {
  group('$_DefaultSentryLoggerFormatter', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    void verifyPassedAttributes(Map<String, SentryAttribute> attributes) {
      expect(attributes['foo']?.type, 'string');
      expect(attributes['foo']?.value, 'bar');
    }

    void verifyBasicTemplate(SentryLog log) {
      expect(log.body, 'Hello, World!');
      expect(log.attributes['sentry.message.template']?.type, 'string');
      expect(log.attributes['sentry.message.template']?.value, 'Hello, %s!');
      expect(log.attributes['sentry.message.parameter.0']?.type, 'string');
      expect(log.attributes['sentry.message.parameter.0']?.value, 'World');
      verifyPassedAttributes(log.attributes);
    }

    void verifyTemplateWithMultipleArguments(SentryLog log) {
      expect(log.body, 'Name: Alice, Age: 30, Active: true, Score: 95.5');
      expect(log.attributes['sentry.message.template']?.type, 'string');
      expect(log.attributes['sentry.message.template']?.value,
          'Name: %s, Age: %s, Active: %s, Score: %s');
      expect(log.attributes['sentry.message.parameter.0']?.type, 'string');
      expect(log.attributes['sentry.message.parameter.0']?.value, 'Alice');
      expect(log.attributes['sentry.message.parameter.1']?.type, 'integer');
      expect(log.attributes['sentry.message.parameter.1']?.value, 30);
      expect(log.attributes['sentry.message.parameter.2']?.type, 'boolean');
      expect(log.attributes['sentry.message.parameter.2']?.value, true);
      expect(log.attributes['sentry.message.parameter.3']?.type, 'double');
      expect(log.attributes['sentry.message.parameter.3']?.value, 95.5);
      verifyPassedAttributes(log.attributes);
    }

    group('format basic template', () {
      test('for trace', () async {
        await fixture.logger.fmt.trace(
          "Hello, %s!",
          ["World"],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        verifyBasicTemplate(fixture.capturedLogs[0]);
      });

      test('for debug', () async {
        await fixture.logger.fmt.debug(
          "Hello, %s!",
          ["World"],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        verifyBasicTemplate(fixture.capturedLogs[0]);
      });

      test('for info', () async {
        await fixture.logger.fmt.info(
          "Hello, %s!",
          ["World"],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        verifyBasicTemplate(fixture.capturedLogs[0]);
      });

      test('for warn', () async {
        await fixture.logger.fmt.warn(
          "Hello, %s!",
          ["World"],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        verifyBasicTemplate(fixture.capturedLogs[0]);
      });

      test('for error', () async {
        await fixture.logger.fmt.error(
          "Hello, %s!",
          ["World"],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        verifyBasicTemplate(fixture.capturedLogs[0]);
      });

      test('for fatal', () async {
        await fixture.logger.fmt.fatal(
          "Hello, %s!",
          ["World"],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        verifyBasicTemplate(fixture.capturedLogs[0]);
      });
    });

    group('template with multiple arguments', () {
      test('for trace', () async {
        await fixture.logger.fmt.trace(
          "Name: %s, Age: %s, Active: %s, Score: %s",
          ['Alice', 30, true, 95.5],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        verifyTemplateWithMultipleArguments(fixture.capturedLogs[0]);
      });

      test('for debug', () async {
        await fixture.logger.fmt.debug(
          "Name: %s, Age: %s, Active: %s, Score: %s",
          ['Alice', 30, true, 95.5],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        verifyTemplateWithMultipleArguments(fixture.capturedLogs[0]);
      });

      test('for info', () async {
        await fixture.logger.fmt.info(
          "Name: %s, Age: %s, Active: %s, Score: %s",
          ['Alice', 30, true, 95.5],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        verifyTemplateWithMultipleArguments(fixture.capturedLogs[0]);
      });

      test('for warn', () async {
        await fixture.logger.fmt.warn(
          "Name: %s, Age: %s, Active: %s, Score: %s",
          ['Alice', 30, true, 95.5],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        verifyTemplateWithMultipleArguments(fixture.capturedLogs[0]);
      });

      test('for error', () async {
        await fixture.logger.fmt.error(
          "Name: %s, Age: %s, Active: %s, Score: %s",
          ['Alice', 30, true, 95.5],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        verifyTemplateWithMultipleArguments(fixture.capturedLogs[0]);
      });

      test('for fatal', () async {
        await fixture.logger.fmt.fatal(
          "Name: %s, Age: %s, Active: %s, Score: %s",
          ['Alice', 30, true, 95.5],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        verifyTemplateWithMultipleArguments(fixture.capturedLogs[0]);
      });
    });

    group('template with no arguments', () {
      test('for trace', () async {
        await fixture.logger.fmt.trace(
          "Hello, World!",
          [],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        final log = fixture.capturedLogs[0];
        expect(log.body, 'Hello, World!');
        expect(log.attributes['sentry.message.template'], isNull);
        expect(log.attributes['sentry.message.parameter.0'], isNull);
        verifyPassedAttributes(log.attributes);
      });

      test('for debug', () async {
        await fixture.logger.fmt.debug(
          "Hello, World!",
          [],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        final log = fixture.capturedLogs[0];
        expect(log.body, 'Hello, World!');
        expect(log.attributes['sentry.message.template'], isNull);
        expect(log.attributes['sentry.message.parameter.0'], isNull);
        verifyPassedAttributes(log.attributes);
      });

      test('for info', () async {
        await fixture.logger.fmt.info(
          "Hello, World!",
          [],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        final log = fixture.capturedLogs[0];
        expect(log.body, 'Hello, World!');
        expect(log.attributes['sentry.message.template'], isNull);
        expect(log.attributes['sentry.message.parameter.0'], isNull);
        verifyPassedAttributes(log.attributes);
      });

      test('for warn', () async {
        await fixture.logger.fmt.warn(
          "Hello, World!",
          [],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        final log = fixture.capturedLogs[0];
        expect(log.body, 'Hello, World!');
        expect(log.attributes['sentry.message.template'], isNull);
        expect(log.attributes['sentry.message.parameter.0'], isNull);
        verifyPassedAttributes(log.attributes);
      });

      test('for error', () async {
        await fixture.logger.fmt.error(
          "Hello, World!",
          [],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        final log = fixture.capturedLogs[0];
        expect(log.body, 'Hello, World!');
        expect(log.attributes['sentry.message.template'], isNull);
        expect(log.attributes['sentry.message.parameter.0'], isNull);
        verifyPassedAttributes(log.attributes);
      });

      test('for fatal', () async {
        await fixture.logger.fmt.fatal(
          "Hello, World!",
          [],
          attributes: {'foo': SentryAttribute.string('bar')},
        );

        expect(fixture.capturedLogs.length, 1);
        final log = fixture.capturedLogs[0];
        expect(log.body, 'Hello, World!');
        expect(log.attributes['sentry.message.template'], isNull);
        expect(log.attributes['sentry.message.parameter.0'], isNull);
        verifyPassedAttributes(log.attributes);
      });
    });
  });
}

// Used to reference the private class in the group name
// ignore: camel_case_types
class _DefaultSentryLoggerFormatter {}

class Fixture {
  final capturedLogs = <SentryLog>[];
  final options = defaultTestOptions();
  late final SentryLogger logger;
  late final Scope scope;

  Fixture() {
    scope = Scope(options);
    logger = DefaultSentryLogger(
      captureLogCallback: (log, {scope}) {
        capturedLogs.add(log);
      },
      clockProvider: () => DateTime.now(),
      scopeProvider: () => scope,
    );
  }
}
