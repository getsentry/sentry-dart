import 'package:sentry/sentry.dart';
import 'package:test/test.dart';

void main() {
  group('$SentryBaggageHeader', () {
    test('name is baggage', () {
      final baggage = SentryBaggageHeader('');

      expect(baggage.name, 'baggage');
    });

    test('baggage header from baggage', () {
      final baggage = SentryBaggage({});
      final id = SentryId.newId().toString();
      baggage.setTraceId(id);
      baggage.setPublicKey('publicKey');
      baggage.setRelease('release');
      baggage.setEnvironment('environment');
      baggage.setUserId('userId');
      // ignore: deprecated_member_use_from_same_package
      baggage.setUserSegment('userSegment');
      baggage.setTransaction('transaction');
      baggage.setSampleRate('1.0');
      baggage.setSampled('false');
      final replayId = SentryId.newId().toString();
      baggage.setReplayId(replayId);

      final baggageHeader = SentryBaggageHeader.fromBaggage(baggage);

      expect(
          baggageHeader.value,
          'sentry-trace_id=$id,'
          'sentry-public_key=publicKey,'
          'sentry-release=release,'
          'sentry-environment=environment,'
          'sentry-user_id=userId,'
          'sentry-user_segment=userSegment,'
          'sentry-transaction=transaction,'
          'sentry-sample_rate=1.0,'
          'sentry-sampled=false,'
          'sentry-replay_id=$replayId');
    });
  });
}
