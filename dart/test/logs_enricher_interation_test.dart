@TestOn('vm')
library;

import 'package:sentry/src/logs_enricher_integration.dart';
import 'package:test/test.dart';
import 'package:sentry/src/hub.dart';
import 'package:sentry/src/protocol/sentry_log.dart';
import 'package:sentry/src/protocol/sentry_log_attribute.dart';
import 'package:sentry/src/protocol/sentry_id.dart';
import 'package:sentry/src/protocol/sentry_log_level.dart';
import 'test_utils.dart';

void main() {
  SentryLog givenLog() {
    return SentryLog(
      timestamp: DateTime.now(),
      traceId: SentryId.newId(),
      level: SentryLogLevel.info,
      body: 'test',
      attributes: {
        'attribute': SentryLogAttribute.string('value'),
      },
    );
  }

  group('LogsEnricherIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds itself to sdk.integrations', () {
      expect(
        fixture.options.sdk.integrations
            .contains(LogsEnricherIntegration.integrationName),
        true,
      );
    });

    test('adds os.name and os.version to log attributes on beforeSendLog',
        () async {
      final log = givenLog();
      await fixture.hub.captureLog(log);

      expect(log.attributes['os.name'], isNotNull);
      expect(log.attributes['os.version'], isNotNull);
    });
  });
}

class Fixture {
  final options = defaultTestOptions();
  late final hub = Hub(options);
  late final LogsEnricherIntegration integration;

  Fixture() {
    options.enableLogs = true;

    integration = LogsEnricherIntegration();
    integration.call(hub, options);
  }
}
