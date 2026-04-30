import 'package:sentry/sentry.dart';
import 'package:sentry/src/track_before_send_usage_integration.dart';
import 'package:test/test.dart';

import 'mocks/mock_hub.dart';
import 'test_utils.dart';

void main() {
  group(TrackBeforeSendUsageIntegration, () {
    late Fixture fixture;

    setUp(() {
      fixture = Fixture();
    });

    test('adds itself to sdk.integrations', () {
      fixture.getSut().call(fixture.hub, fixture.options);

      expect(fixture.options.sdk.integrations,
          contains('TrackBeforeSendUsageIntegration'));
    });

    test('adds beforeSendEvent feature when beforeSend is configured', () {
      fixture.options.beforeSend = (event, hint) => event;

      fixture.getSut().call(fixture.hub, fixture.options);

      expect(fixture.options.sdk.features,
          contains(SentryFeatures.beforeSendEvent));
    });

    test('adds beforeSendTransaction feature when configured', () {
      fixture.options.beforeSendTransaction =
          (transaction, hint) => transaction;

      fixture.getSut().call(fixture.hub, fixture.options);

      expect(fixture.options.sdk.features,
          contains(SentryFeatures.beforeSendTransaction));
    });

    test('adds beforeSendFeedback feature when configured', () {
      fixture.options.beforeSendFeedback = (event, hint) => event;

      fixture.getSut().call(fixture.hub, fixture.options);

      expect(fixture.options.sdk.features,
          contains(SentryFeatures.beforeSendFeedback));
    });

    test('adds beforeSendLog feature when configured', () {
      fixture.options.beforeSendLog = (log) => log;

      fixture.getSut().call(fixture.hub, fixture.options);

      expect(
          fixture.options.sdk.features, contains(SentryFeatures.beforeSendLog));
    });

    test('adds beforeSendMetric feature when configured', () {
      fixture.options.beforeSendMetric = (metric) => metric;

      fixture.getSut().call(fixture.hub, fixture.options);

      expect(fixture.options.sdk.features,
          contains(SentryFeatures.beforeSendMetric));
    });

    test('does not add features when callbacks are not set', () {
      fixture.getSut().call(fixture.hub, fixture.options);

      expect(fixture.options.sdk.features,
          isNot(contains(SentryFeatures.beforeSendEvent)));
      expect(fixture.options.sdk.features,
          isNot(contains(SentryFeatures.beforeSendTransaction)));
      expect(fixture.options.sdk.features,
          isNot(contains(SentryFeatures.beforeSendFeedback)));
      expect(fixture.options.sdk.features,
          isNot(contains(SentryFeatures.beforeSendLog)));
      expect(fixture.options.sdk.features,
          isNot(contains(SentryFeatures.beforeSendMetric)));
    });
  });
}

class Fixture {
  final hub = MockHub();
  final options = defaultTestOptions();

  TrackBeforeSendUsageIntegration getSut() {
    return TrackBeforeSendUsageIntegration();
  }
}
