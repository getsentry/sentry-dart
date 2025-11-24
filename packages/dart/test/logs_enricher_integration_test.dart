@TestOn('vm')
library;

import 'package:sentry/src/logs_enricher_integration.dart';
import 'package:test/test.dart';
import 'package:sentry/src/hub.dart';
import 'package:sentry/src/protocol/sentry_log.dart';
import 'package:sentry/src/protocol/sentry_attribute.dart';
import 'package:sentry/src/protocol/sentry_id.dart';
import 'package:sentry/src/protocol/sentry_log_level.dart';
import 'test_utils.dart';
import 'package:sentry/src/utils/os_utils.dart';

void main() {
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

  group('LogsEnricherIntegration', () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds itself to sdk.integrations if enableLogs is true', () {
      fixture.options.enableLogs = true;
      fixture.addIntegration();

      expect(
        fixture.options.sdk.integrations
            .contains(LogsEnricherIntegration.integrationName),
        true,
      );
    });

    test('does not add itself to sdk.integrations if enableLogs is false', () {
      fixture.options.enableLogs = false;
      fixture.addIntegration();

      expect(
        fixture.options.sdk.integrations
            .contains(LogsEnricherIntegration.integrationName),
        false,
      );
    });

    test(
        'adds os.name and os.version to log attributes on OnBeforeCaptureLog lifecycle event',
        () async {
      fixture.options.enableLogs = true;
      fixture.addIntegration();

      final log = givenLog();
      await fixture.hub.captureLog(log);

      final os = getSentryOperatingSystem();

      expect(log.attributes['os.name']?.value, os.name);
      expect(log.attributes['os.version']?.value, os.version);
    });

    test(
        'does not add os.name and os.version to log attributes if enableLogs is false',
        () async {
      fixture.options.enableLogs = false;
      fixture.addIntegration();

      final log = givenLog();
      await fixture.hub.captureLog(log);

      expect(log.attributes['os.name'], isNull);
      expect(log.attributes['os.version'], isNull);
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
  }

  void addIntegration() {
    integration.call(hub, options);
  }
}
