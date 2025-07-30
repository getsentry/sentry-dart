import 'package:sentry/sentry.dart';
import 'package:sentry/src/sentry_envelope_header.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('SentryEnvelopeHeader', () {
    test('toJson empty', () {
      final sut = SentryEnvelopeHeader(null, null);
      final expected = <String, dynamic>{};
      expect(sut.toJson(), expected);
    });

    test('toJson', () async {
      final eventId = SentryId.newId();
      final sdkVersion = SdkVersion(
        name: 'fixture-sdkName',
        version: 'fixture-version',
      );
      final context = SentryTraceContextHeader.fromJson(<String, dynamic>{
        'trace_id': '${SentryId.newId()}',
        'public_key': '123',
      });
      final timestamp = DateTime.utc(2019);
      final sut = SentryEnvelopeHeader(
        eventId,
        sdkVersion,
        dsn: fakeDsn,
        traceContext: context,
        sentAt: timestamp,
      );
      final expextedSkd = sdkVersion.toJson();
      final expected = <String, dynamic>{
        'event_id': eventId.toString(),
        'sdk': expextedSkd,
        'trace': context.toJson(),
        'dsn': fakeDsn,
        'sent_at': formatDateAsIso8601WithMillisPrecision(timestamp),
      };
      expect(sut.toJson(), expected);
    });
  });
}
