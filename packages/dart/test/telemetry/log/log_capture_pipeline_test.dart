import 'package:sentry/sentry.dart';
import 'package:sentry/src/client_reports/discard_reason.dart';
import 'package:sentry/src/telemetry/log/log_capture_pipeline.dart';
import 'package:sentry/src/transport/data_category.dart';
import 'package:test/test.dart';

import '../../mocks/mock_client_report_recorder.dart';
import '../../mocks/mock_telemetry_processor.dart';
import '../../test_utils.dart';

void main() {
  group('$LogCapturePipeline', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    SentryLog givenLog() {
      return SentryLog(
        timestamp: DateTime.now(),
        traceId: SentryId.newId(),
        level: SentryLogLevel.info,
        body: 'test',
        attributes: {
          'attribute': SentryAttribute.string('value'),
        },
      );
    }

    group('when capturing a log', () {
      test('forwards to telemetry processor', () async {
        final log = givenLog();

        await fixture.pipeline.captureLog(log, scope: fixture.scope);

        expect(fixture.processor.addedLogs.length, 1);
        expect(fixture.processor.addedLogs.first, same(log));
      });

      test('adds default attributes', () async {
        await fixture.scope.setUser(SentryUser(id: 'user-id'));
        fixture.scope.setAttributes({
          'scope-key': SentryAttribute.string('scope-value'),
        });

        final log = givenLog()
          ..attributes['custom'] = SentryAttribute.string('log-value');

        await fixture.pipeline.captureLog(log, scope: fixture.scope);

        final attributes = log.attributes;
        expect(attributes['scope-key']?.value, 'scope-value');
        expect(attributes['custom']?.value, 'log-value');
        expect(attributes[SemanticAttributesConstants.sentryEnvironment]?.value,
            'test-env');
        expect(attributes[SemanticAttributesConstants.sentryRelease]?.value,
            'test-release');
        expect(attributes[SemanticAttributesConstants.sentrySdkName]?.value,
            fixture.options.sdk.name);
        expect(attributes[SemanticAttributesConstants.sentrySdkVersion]?.value,
            fixture.options.sdk.version);
        expect(
            attributes[SemanticAttributesConstants.userId]?.value, 'user-id');
      });

      test('prefers log attributes over scope attributes', () async {
        fixture.scope.setAttributes({
          'overridden': SentryAttribute.string('scope-value'),
          'kept': SentryAttribute.bool(true),
        });

        final log = givenLog()
          ..attributes['overridden'] = SentryAttribute.string('log-value')
          ..attributes['logOnly'] = SentryAttribute.double(1.23);

        await fixture.pipeline.captureLog(log, scope: fixture.scope);

        final attributes = log.attributes;
        expect(attributes['overridden']?.value, 'log-value');
        expect(attributes['kept']?.value, true);
        expect(attributes['logOnly']?.type, 'double');
      });

      test('dispatches OnProcessLog after scope merge but before beforeSendLog',
          () async {
        final operations = <String>[];
        bool hasScopeAttrInCallback = false;

        fixture.scope.setAttributes({
          'scope-attr': SentryAttribute.string('scope-value'),
        });

        fixture.options.lifecycleRegistry
            .registerCallback<OnProcessLog>((event) {
          operations.add('onProcessLog');
          hasScopeAttrInCallback =
              event.log.attributes.containsKey('scope-attr');
        });

        fixture.options.beforeSendLog = (log) {
          operations.add('beforeSendLog');
          return log;
        };

        final log = givenLog();

        await fixture.pipeline.captureLog(log, scope: fixture.scope);

        expect(operations, ['onProcessLog', 'beforeSendLog']);
        expect(hasScopeAttrInCallback, isTrue);
      });

      test('keeps attributes added by lifecycle callbacks', () async {
        fixture.options.lifecycleRegistry
            .registerCallback<OnProcessLog>((event) {
          event.log.attributes['callback-key'] =
              SentryAttribute.string('callback-value');
          event.log.attributes[SemanticAttributesConstants.sentryEnvironment] =
              SentryAttribute.string('callback-env');
        });

        final log = givenLog();

        await fixture.pipeline.captureLog(log, scope: fixture.scope);

        final attributes = log.attributes;
        expect(attributes['callback-key']?.value, 'callback-value');
        expect(attributes[SemanticAttributesConstants.sentryEnvironment]?.value,
            'callback-env');
      });

      test('does not add user attributes when sendDefaultPii is false',
          () async {
        fixture.options.sendDefaultPii = false;
        await fixture.scope.setUser(SentryUser(id: 'user-id'));

        final log = givenLog();

        await fixture.pipeline.captureLog(log, scope: fixture.scope);

        expect(
          log.attributes.containsKey(SemanticAttributesConstants.userId),
          isFalse,
        );
      });
    });

    group('when logs are disabled', () {
      test('does not add logs to processor', () async {
        fixture.options.enableLogs = false;

        final log = givenLog();

        await fixture.pipeline.captureLog(log, scope: fixture.scope);

        expect(fixture.processor.addedLogs, isEmpty);
      });
    });

    group('when beforeSendLog is configured', () {
      test('returning null drops the log', () async {
        fixture.options.beforeSendLog = (_) => null;

        final log = givenLog();

        await fixture.pipeline.captureLog(log, scope: fixture.scope);

        expect(fixture.processor.addedLogs, isEmpty);
      });

      test('returning null records lost event in client report', () async {
        fixture.options.beforeSendLog = (_) => null;

        final log = givenLog();

        await fixture.pipeline.captureLog(log, scope: fixture.scope);

        expect(fixture.recorder.discardedEvents.length, 1);
        expect(fixture.recorder.discardedEvents.first.reason,
            DiscardReason.beforeSend);
        expect(fixture.recorder.discardedEvents.first.category,
            DataCategory.logItem);
      });

      test('can mutate the log', () async {
        fixture.options.beforeSendLog = (log) {
          log.body = 'modified-body';
          log.attributes['added-key'] = SentryAttribute.string('added');
          return log;
        };

        final log = givenLog();

        await fixture.pipeline.captureLog(log, scope: fixture.scope);

        expect(fixture.processor.addedLogs.length, 1);
        final captured = fixture.processor.addedLogs.first;
        expect(captured.body, 'modified-body');
        expect(captured.attributes['added-key']?.value, 'added');
      });

      test('async callback is awaited', () async {
        fixture.options.beforeSendLog = (log) async {
          await Future.delayed(Duration(milliseconds: 10));
          log.body = 'async-modified';
          return log;
        };

        final log = givenLog();

        await fixture.pipeline.captureLog(log, scope: fixture.scope);

        expect(fixture.processor.addedLogs.length, 1);
        final captured = fixture.processor.addedLogs.first;
        expect(captured.body, 'async-modified');
      });

      test('exception in callback is caught and log is still captured',
          () async {
        fixture.options.automatedTestMode = false;
        fixture.options.beforeSendLog = (log) {
          throw Exception('test');
        };

        final log = givenLog();

        await fixture.pipeline.captureLog(log, scope: fixture.scope);

        expect(fixture.processor.addedLogs.length, 1);
        final captured = fixture.processor.addedLogs.first;
        expect(captured.body, 'test');
      });
    });
  });
}

class Fixture {
  final options = defaultTestOptions()
    ..environment = 'test-env'
    ..release = 'test-release'
    ..sendDefaultPii = true
    ..enableLogs = true;

  final processor = MockTelemetryProcessor();
  final recorder = MockClientReportRecorder();

  late final Scope scope;
  late final LogCapturePipeline pipeline;

  Fixture() {
    options.telemetryProcessor = processor;
    options.recorder = recorder;
    scope = Scope(options);
    pipeline = LogCapturePipeline(options);
  }
}
